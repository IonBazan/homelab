#!/usr/bin/with-contenv bash
# Runs as root from /custom-cont-init.d on every start, after the image has seeded
# qBittorrent.conf and before qBittorrent launches. Writes WebUI\Username and
# WebUI\Password_PBKDF2 (PBKDF2-HMAC-SHA512, 100k iterations, qBittorrent's own
# format) from QBITTORRENT_USERNAME / QBITTORRENT_PASSWORD, and
# WebUI\TrustedReverseProxiesList from TRUSTED_PROXIES. A matching login is
# left untouched; an empty password leaves the login to qBittorrent.
exec python3 - <<'EOF'
import base64
import hashlib
import os

CONF = "/config/qBittorrent/qBittorrent.conf"


def pbkdf2(password, salt):
    return hashlib.pbkdf2_hmac("sha512", password.encode(), salt, 100_000, 64)


def password_matches(existing, password):
    try:
        body = existing.strip('"')[len("@ByteArray(") : -1]
        salt_b64, hash_b64 = body.split(":", 1)
        return pbkdf2(password, base64.b64decode(salt_b64)) == base64.b64decode(hash_b64)
    except Exception:
        return False


def read_pref(lines, key):
    section = None
    for i, line in enumerate(lines):
        s = line.strip()
        if s.startswith("[") and s.endswith("]"):
            section = s
        elif section == "[Preferences]" and s.startswith(key + "="):
            return i, s[len(key) + 1 :]
    return None, None


def set_pref(lines, key, value):
    idx, _ = read_pref(lines, key)
    if idx is not None:
        lines[idx] = f"{key}={value}"
        return
    if "[Preferences]" not in lines:
        lines += ["", "[Preferences]"]
    start = lines.index("[Preferences]")
    end = next(
        (i for i in range(start + 1, len(lines)) if lines[i].startswith("[")),
        len(lines),
    )
    lines.insert(end, f"{key}={value}")


password = os.environ.get("QBITTORRENT_PASSWORD", "")
username = os.environ.get("QBITTORRENT_USERNAME", "admin")
proxies = os.environ.get("TRUSTED_PROXIES", "")

with open(CONF) as fh:
    lines = fh.read().splitlines()
changed = False

_, cur_proxies = read_pref(lines, r"WebUI\TrustedReverseProxiesList")
if proxies and cur_proxies != proxies:
    set_pref(lines, r"WebUI\TrustedReverseProxiesList", proxies)
    changed = True
    print(f"[webui-login] trusted reverse proxies set to {proxies}")

_, cur_user = read_pref(lines, r"WebUI\Username")
_, cur_pass = read_pref(lines, r"WebUI\Password_PBKDF2")
if not password:
    print("[webui-login] QBITTORRENT_PASSWORD empty, leaving the WebUI login to qBittorrent")
elif cur_user == username and cur_pass and password_matches(cur_pass, password):
    print("[webui-login] WebUI login already matches QBITTORRENT_PASSWORD")
else:
    salt = os.urandom(16)
    value = "@ByteArray({}:{})".format(
        base64.b64encode(salt).decode(), base64.b64encode(pbkdf2(password, salt)).decode()
    )
    set_pref(lines, r"WebUI\Username", username)
    set_pref(lines, r"WebUI\Password_PBKDF2", f'"{value}"')
    changed = True
    print(f"[webui-login] applied WebUI login for user '{username}'")

if changed:
    with open(CONF, "w") as fh:
        fh.write("\n".join(lines) + "\n")
EOF
