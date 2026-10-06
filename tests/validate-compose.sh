#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export DOMAIN_NAME="test.tld"
export TZ="Asia/Singapore"
export PUID="1000"
export PGID="1000"
export PHYSICAL_SERVER_IP="127.0.0.1"
export PHYSICAL_SERVER_NETWORK="127.0.0.0/8"
export PUBLIC_DOMAIN="test.tld"
export CF_ZONE_ID="test"
export MEDIA_DIR="/tmp/media"
export BACKUP_DIR="/tmp/backups"
export CF_DNS_API_TOKEN="test"
export CF_API_EMAIL="test@test.tld"
export TAILSCALE_TOKEN="test"
export POCKET_ID_ENCRYPTION_KEY="test"
export HOMARR_SECRET_ENCRYPTION_KEY="test"
export TRACEARR_JWT_SECRET="test"
export TRACEARR_COOKIE_SECRET="test"

set -x

docker compose --env-file /dev/null config --quiet
COMPOSE_FILE=docker-compose.yaml:docker-compose.ports.yaml \
  docker compose --env-file /dev/null config --quiet
TINYAUTH_ENABLED=true docker compose --env-file /dev/null config --quiet
for script in scripts/*.sh apps/config/qbittorrent/webui-login.sh; do bash -n "$script"; done

{ set +x; } 2>/dev/null

services_for_profile() { docker compose --env-file /dev/null --profile "$1" config --services 2>/dev/null; }

check() {
  local expect=$1 profile=$2 service=$3 list found
  list=$(services_for_profile "$profile" || true)
  if grep -qx -- "$service" <<<"$list"; then found=present; else found=absent; fi
  if [ "$found" != "$expect" ]; then
    echo "FAIL: expected '$service' to be $expect under profile '$profile' (was $found)" >&2
    exit 1
  fi
  echo "ok: $service is $expect under profile '$profile'"
}

# every app file's profile starts the service of the same name on its own
for file in apps/*/*.yaml; do
  app=$(basename "$file" .yaml)
  check present "$app" "$app"
done

check absent all       traefik
check present traefik  traefik
check absent all       pihole
check present pihole   pihole
check absent all       tailscale
check present tailscale tailscale
check present full     homarr
check present homarr   homarr
check absent  tools    homarr

check present media    plex
check present media    seerr
check present arrs     seerr
check present arrs     radarr
check absent  arrs     flaresolverr
check absent  media    flaresolverr
check absent  default  flaresolverr
check present full     flaresolverr
check present flaresolverr flaresolverr
check absent  flaresolverr prowlarr
check absent  arrs     plex
check absent  media    homepage
check present vpn      gluetun
check present automation homeassistant
check absent  default  homeassistant
check absent  basic    homebridge
check present full     homebridge
check absent  vpn      plex
check present auth     tinyauth
check present auth     traefik
check present tinyauth pocket-id
check absent  tinyauth traefik
check absent  default  tinyauth
check absent  full     configarr
check present configarr configarr
check present configarr sonarr
check present configarr flaresolverr

echo "OK"
