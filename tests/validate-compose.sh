#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export DOMAIN_NAME="test.tld"
export PHYSICAL_SERVER_IP="127.0.0.1"
export PUBLIC_DOMAIN="test.tld"
export MEDIA_DIR="/tmp/media"

set -x

docker compose --env-file /dev/null config --quiet
COMPOSE_FILE=docker-compose.yaml:docker-compose.ports.yaml \
  docker compose --env-file /dev/null config --quiet

{ set +x; } 2>/dev/null

services_for_profile() { docker compose --env-file /dev/null --profile "$1" config --services 2>/dev/null; }

check() {
  local expect=$1 profile=$2 service=$3 list found
  list=$(services_for_profile "$profile")
  if grep -qx -- "$service" <<<"$list"; then found=present; else found=absent; fi
  if [ "$found" != "$expect" ]; then
    echo "FAIL: expected '$service' to be $expect under profile '$profile' (was $found)" >&2
    exit 1
  fi
  echo "ok: $service is $expect under profile '$profile'"
}

check absent all       traefik
check present traefik  traefik
check absent all       pihole
check present pihole   pihole
check absent all       tailscale
check present tailscale tailscale

check present media    plex
check present arrs     radarr
check absent  arrs     plex
check absent  media    homepage
check present vpn      gluetun
check absent  vpn      plex

echo "OK"
