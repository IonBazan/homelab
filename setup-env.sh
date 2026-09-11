#!/usr/bin/env bash
#
# Bootstrap the env files for this stack:
#   * create .env from .env.example (if missing)
#   * fill every blank secret that can be random - API keys, encryption/JWT
#     secrets, qBittorrent + Pi-hole + Tracearr DB passwords
#   * detect host values - LAN IP, LAN CIDR, timezone, PUID/PGID
#   * scaffold .env.gluetun from the template
#
# Safe to re-run: your own values are never touched (detected host values
# overwrite only a still-default placeholder). Tokens that must come from a
# provider (Cloudflare, Plex, Tailscale, ...) are listed at the end.
set -euo pipefail

cd "$(dirname "$0")"

command -v openssl >/dev/null || { echo "openssl is required" >&2; exit 1; }

ENV_FILE=".env"
GLUETUN_FILE=".env.gluetun"

rand_hex()  { openssl rand -hex "$1"; }
rand_pass() { openssl rand -base64 24 | tr -d '/+=\n'; }

# raw_value KEY FILE -> value of the first uncommented KEY= line, with a trailing
# " # comment" and any surrounding quotes stripped
raw_value() {
  grep -E "^$1=" "$2" 2>/dev/null | head -1 | sed -E "
    s/^$1=//
    s/[[:space:]]+#.*$//
    s/^[[:space:]]+//; s/[[:space:]]+$//
    s/^\"(.*)\"\$/\1/; s/^'(.*)'\$/\1/
  "
}

# env_has_value KEY FILE -> 0 if that line has a non-empty value
env_has_value() { [ -n "$(raw_value "$1" "$2")" ]; }

# set_env KEY VALUE FILE -> replace the uncommented line, else the commented one,
# else append. Any trailing "# comment" on the original line is kept.
# Values here are always [A-Za-z0-9./] so no escaping is needed.
set_env() {
  local key=$1 val=$2 file=$3 tmp
  tmp=$(mktemp)
  awk -v key="$key" -v val="$val" '
    function emit(line,   c) {
      c = (match(line, /[[:space:]]+#.*$/)) ? substr(line, RSTART, RLENGTH) : ""
      print key "=\"" val "\"" c
    }
    BEGIN { done = 0 }
    !done && $0 ~ "^" key "="                         { emit($0); done = 1; next }
    !done && $0 ~ "^[[:space:]]*#[[:space:]]*" key "=" { emit($0); done = 1; next }
    { print }
    END { if (!done) print key "=\"" val "\"" }
  ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# net_of IP PREFIX -> network address in IP/PREFIX form (POSIX awk, no bit ops)
net_of() {
  awk -v ip="$1" -v p="$2" 'BEGIN {
    split(ip, o, ".")
    for (i = 1; i <= 4; i++) {
      bits = p - (i - 1) * 8
      m = (bits >= 8) ? 255 : (bits <= 0) ? 0 : 256 - 2 ^ (8 - bits)
      r = 0; b = 1
      for (k = 0; k < 8; k++) {
        if (int(o[i] / b) % 2 && int(m / b) % 2) r += b
        b *= 2
      }
      net[i] = r
    }
    printf "%d.%d.%d.%d/%d", net[1], net[2], net[3], net[4], p
  }'
}

# detect_ip_cidr -> "<ip> <network/prefix>" for the default-route interface
detect_ip_cidr() {
  local ip prefix iface mask hex byte
  if command -v ip >/dev/null 2>&1; then
    set -- $(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i=="src")s=$(i+1);if($i=="dev")d=$(i+1)}print s,d;exit}')
    ip=${1:-}; iface=${2:-}
    [ -n "$iface" ] && prefix=$(ip -4 -o addr show dev "$iface" 2>/dev/null | awk '/inet /{split($4,a,"/");print a[2];exit}')
  elif command -v route >/dev/null 2>&1; then
    iface=$(route -n get default 2>/dev/null | awk '/interface:/{print $2;exit}')
    [ -n "$iface" ] && ip=$(ipconfig getifaddr "$iface" 2>/dev/null || true)
    mask=$(ifconfig "$iface" 2>/dev/null | awk '/inet /{print $4;exit}')
    if [ -n "${mask:-}" ]; then
      hex=${mask#0x}; prefix=0
      for i in 0 2 4 6; do
        byte=$((16#${hex:$i:2}))
        while [ "$byte" -gt 0 ]; do prefix=$((prefix + (byte & 1))); byte=$((byte >> 1)); done
      done
    fi
  fi
  [ -n "${ip:-}" ] && [ -n "${prefix:-}" ] || return 1
  printf '%s %s\n' "$ip" "$(net_of "$ip" "$prefix")"
}

detect_tz() {
  if command -v timedatectl >/dev/null 2>&1; then
    timedatectl show -p Timezone --value 2>/dev/null && return
  fi
  [ -f /etc/timezone ] && { cat /etc/timezone; return; }
  [ -L /etc/localtime ] && readlink /etc/localtime | sed -e 's#.*/zoneinfo/##'
}

# --- .env -------------------------------------------------------------------
if [ ! -f "$ENV_FILE" ]; then
  cp .env.example "$ENV_FILE"
  echo "created $ENV_FILE from .env.example"
fi

# fill_detected KEY VALUE -> set only if current value is empty or still the
# placeholder shipped in .env.example (so a value you edited is never clobbered)
fill_detected() {
  local key=$1 val=$2 cur
  if [ -z "$val" ]; then
    printf '  %-24s not detected, left as-is\n' "$key"
    return
  fi
  cur=$(raw_value "$key" "$ENV_FILE")
  if [ "$cur" = "$val" ]; then
    printf '  %-24s %s\n' "$key" "$val"
  elif [ -z "$cur" ] || [ "$cur" = "$(raw_value "$key" .env.example)" ]; then
    set_env "$key" "$val" "$ENV_FILE"
    printf '  %-24s %s\n' "$key" "$val"
  else
    printf '  %-24s kept (%s)\n' "$key" "$cur"
  fi
}

echo
echo "Host:"
ipcidr=$(detect_ip_cidr || true)
fill_detected PHYSICAL_SERVER_IP      "${ipcidr%% *}"
fill_detected PHYSICAL_SERVER_NETWORK "$([ -n "$ipcidr" ] && echo "${ipcidr#* }")"
fill_detected TZ                      "$(detect_tz || true)"
if [ "$(id -u)" != "0" ]; then
  fill_detected PUID "$(id -u)"
  fill_detected PGID "$(id -g)"
else
  echo "  PUID/PGID                skipped (running as root)"
fi

# key                            generator
GEN=(
  "HOMARR_SECRET_ENCRYPTION_KEY  rand_hex 32"
  "TRACEARR_JWT_SECRET           rand_hex 32"
  "TRACEARR_COOKIE_SECRET        rand_hex 32"
  "SONARR_API_KEY                rand_hex 16"
  "RADARR_API_KEY                rand_hex 16"
  "PROWLARR_API_KEY              rand_hex 16"
  "BAZARR_API_KEY                rand_hex 16"
  "QBITTORRENT_PASSWORD          rand_pass"
  "PIHOLE_PASSWORD               rand_pass"
  "TRACEARR_DB_PASSWORD          rand_pass"
)

echo
echo "Secrets:"
for row in "${GEN[@]}"; do
  set -- $row
  key=$1; shift
  if env_has_value "$key" "$ENV_FILE"; then
    printf '  %-30s kept (already set)\n' "$key"
  else
    set_env "$key" "$("$@")" "$ENV_FILE"
    printf '  %-30s generated\n' "$key"
  fi
done

# --- .env.gluetun ---------------------------------------------------------------
echo
echo "VPN (.env.gluetun):"
if [ ! -e "$GLUETUN_FILE" ]; then
  if [ ! -e .env.gluetun.nordvpn ] && [ ! -e .env.gluetun.wireguard ]; then
    cp .env.gluetun.example .env.gluetun.nordvpn
    echo "  created .env.gluetun.nordvpn"
  fi
  target=.env.gluetun.nordvpn
  [ -e "$target" ] || target=.env.gluetun.wireguard
  ln -sf "$target" "$GLUETUN_FILE"
  echo "  linked .env.gluetun -> $target"
  net=$(raw_value PHYSICAL_SERVER_NETWORK "$ENV_FILE")
  if [ -n "$net" ]; then
    set_env FIREWALL_OUTBOUND_SUBNETS "$net" "$target"
    echo "  set FIREWALL_OUTBOUND_SUBNETS=$net"
  fi
else
  echo "  $GLUETUN_FILE exists, left as-is"
fi

# --- what still needs a human -------------------------------------------------
echo
echo "Still needs a real value in $ENV_FILE (get these from the provider):"
MANUAL=(
  "PLEX_CLAIM|https://www.plex.tv/claim (first run only)"
  "TAILSCALE_TOKEN|Tailscale admin > Settings > Keys"
  "CF_DNS_API_TOKEN|Cloudflare > API Tokens > Edit zone DNS"
  "CF_API_EMAIL|your Cloudflare account email"
  "PLEX_TOKEN|Homepage widget - X-Plex-Token"
  "JELLYFIN_API_KEY|Homepage widget - Jellyfin > Dashboard > API Keys"
  "HOMEASSISTANT_TOKEN|Homepage widget - HA long-lived token"
  "TRAEFIK_DASHBOARD_AUTH|optional - htpasswd hash, \$ doubled to \$\$"
)
any=0
for row in "${MANUAL[@]}"; do
  key=${row%%|*}; hint=${row#*|}
  env_has_value "$key" "$ENV_FILE" || { printf '  %-24s %s\n' "$key" "$hint"; any=1; }
done
[ "$any" -eq 0 ] && echo "  (nothing - all set)"

echo
echo "Review the defaults the script can't guess: DOMAIN_NAME  MEDIA_DIR  COMPOSE_PROFILES  COMPOSE_FILE"
echo "Also edit .env.gluetun: uncomment one provider block and fill the credentials."
