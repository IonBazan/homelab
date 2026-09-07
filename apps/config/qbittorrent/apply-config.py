#!/usr/bin/env python3
"""Seed qBittorrent.conf into the config volume and keep the WebUI login in sync
with the environment.

Runs as the `qbittorrent-config` container before qBittorrent starts:

1. If /config/qBittorrent/qBittorrent.conf is missing, copy it from /seed.conf.
2. If QBITTORRENT_PASSWORD is set, write WebUI\\Username / WebUI\\Password_PBKDF2
   into [Preferences] (PBKDF2-HMAC-SHA512, 100k iterations - qBittorrent's own
   format). Idempotent: an already-matching password is left untouched, so the
   file only changes when you change the env var.
3. chown the tree to PUID:PGID.

If QBITTORRENT_PASSWORD is empty the login is left alone - qBittorrent then owns
it and whatever you set in the UI persists.
"""
import base64
import hashlib
import os
import sys

CONF = "/config/qBittorrent/qBittorrent.conf"
SEED = "/seed.conf"
ITERATIONS = 100_000
DKLEN = 64
SALT_LEN = 16


def pbkdf2(password: str, salt: bytes) -> bytes:
    return hashlib.pbkdf2_hmac("sha512", password.encode(), salt, ITERATIONS, DKLEN)


def encode_value(salt: bytes, digest: bytes) -> str:
    b64 = lambda b: base64.b64encode(b).decode()
    return f'@ByteArray({b64(salt)}:{b64(digest)})'


def password_matches(existing: str, password: str) -> bool:
    """existing is the raw quoted value: "@ByteArray(<salt_b64>:<hash_b64>)" """
    try:
        inner = existing.strip().strip('"')
        body = inner[len("@ByteArray(") : -1]
        salt_b64, hash_b64 = body.split(":", 1)
        salt = base64.b64decode(salt_b64)
        want = base64.b64decode(hash_b64)
        return pbkdf2(password, salt) == want
    except Exception:
        return False


def seed_if_absent() -> None:
    if os.path.isfile(CONF):
        print("qBittorrent.conf present, keeping it")
        return
    os.makedirs(os.path.dirname(CONF), exist_ok=True)
    with open(SEED) as src, open(CONF, "w") as dst:
        dst.write(src.read())
    print("seeded qBittorrent.conf")


def read_pref(lines: list[str], key: str):
    """Return (index, value) of `key=` inside [Preferences], or (None, None)."""
    section = None
    for i, line in enumerate(lines):
        s = line.strip()
        if s.startswith("[") and s.endswith("]"):
            section = s
        elif section == "[Preferences]" and s.startswith(key + "="):
            return i, s[len(key) + 1 :]
    return None, None


def set_pref(lines: list[str], key: str, value: str) -> list[str]:
    idx, _ = read_pref(lines, key)
    if idx is not None:
        lines[idx] = f"{key}={value}"
        return lines
    # insert at the end of [Preferences], creating the section if needed
    try:
        start = lines.index("[Preferences]")
    except ValueError:
        if lines and lines[-1] != "":
            lines.append("")
        lines.append("[Preferences]")
        lines.append(f"{key}={value}")
        return lines
    end = len(lines)
    for i in range(start + 1, len(lines)):
        t = lines[i].strip()
        if t.startswith("[") and t.endswith("]"):
            end = i
            break
    lines.insert(end, f"{key}={value}")
    return lines


def apply_credentials() -> None:
    password = os.environ.get("QBITTORRENT_PASSWORD", "")
    username = os.environ.get("QBITTORRENT_USERNAME", "admin")
    if not password:
        print("QBITTORRENT_PASSWORD empty, leaving WebUI login to qBittorrent")
        return

    with open(CONF) as fh:
        lines = fh.read().splitlines()

    _, cur_user = read_pref(lines, r"WebUI\Username")
    _, cur_pass = read_pref(lines, r"WebUI\Password_PBKDF2")

    if cur_user == username and cur_pass and password_matches(cur_pass, password):
        print("WebUI login already matches QBITTORRENT_PASSWORD")
        return

    salt = os.urandom(SALT_LEN)
    value = encode_value(salt, pbkdf2(password, salt))
    lines = set_pref(lines, r"WebUI\Username", username)
    lines = set_pref(lines, r"WebUI\Password_PBKDF2", f'"{value}"')
    with open(CONF, "w") as fh:
        fh.write("\n".join(lines) + "\n")
    print(f"applied WebUI login for user '{username}' from QBITTORRENT_PASSWORD")


def fix_ownership() -> None:
    try:
        uid = int(os.environ.get("PUID", "1000"))
        gid = int(os.environ.get("PGID", "1000"))
    except ValueError:
        return
    root = os.path.dirname(CONF)
    for dirpath, dirnames, filenames in os.walk(root):
        os.chown(dirpath, uid, gid)
        for name in filenames:
            os.chown(os.path.join(dirpath, name), uid, gid)


def main() -> int:
    seed_if_absent()
    apply_credentials()
    fix_ownership()
    return 0


if __name__ == "__main__":
    sys.exit(main())
