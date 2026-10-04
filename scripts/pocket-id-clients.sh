#!/usr/bin/env bash
#
# Register the stack's OIDC clients in Pocket ID with the IDs and secrets from .env, so no client
# has to be created by hand. Run it on the server once Pocket ID is up at https://id.${DOMAIN_NAME}.
#
# Safe to re-run: an existing client is left alone apart from adding its .env secret when Pocket ID
# does not have it yet, so name, callback and group changes made in the UI stick.
set -euo pipefail

cd "$(dirname "$0")/.."

command -v curl >/dev/null || { echo "curl is required" >&2; exit 1; }

ENV_FILE=".env"

# raw_value KEY FILE -> value of the first uncommented KEY= line, with a trailing
# " # comment" and any surrounding quotes stripped; empty when the key is missing
raw_value() {
  { grep -E "^$1=" "$2" 2>/dev/null || true; } | head -1 | sed -E "
    s/^$1=//
    s/[[:space:]]+#.*$//
    s/^[[:space:]]+//; s/[[:space:]]+$//
    s/^\"(.*)\"\$/\1/; s/^'(.*)'\$/\1/
  "
}

DOMAIN_NAME=$(raw_value DOMAIN_NAME "$ENV_FILE")
API_KEY=$(raw_value POCKET_ID_STATIC_API_KEY "$ENV_FILE")
BASE="https://id.$DOMAIN_NAME/api"

[ -n "$DOMAIN_NAME" ] || { echo "DOMAIN_NAME is not set in $ENV_FILE" >&2; exit 1; }
[ -n "$API_KEY" ] || { echo "POCKET_ID_STATIC_API_KEY is not set in $ENV_FILE (run scripts/setup-env.sh)" >&2; exit 1; }

api() {
  curl -sS -H "X-API-Key: $API_KEY" -H "Content-Type: application/json" "$@"
}

secret_ids() {
  api -f "$BASE/oidc/clients/$1/secrets" | grep -o '"id":"[^"]*"' | cut -d'"' -f4
}

# register <client id> <name> <callback URL> <secret>
register() {
  local id=$1 name=$2 callback=$3 secret=$4 status prefix sid

  if [ -z "$secret" ]; then
    echo "$id: no secret in $ENV_FILE, skipped"
    return
  fi

  status=$(api -o /dev/null -w '%{http_code}' "$BASE/oidc/clients/$id")
  case $status in
    200) ;;
    404)
      api -f -o /dev/null -X POST "$BASE/oidc/clients" \
        -d "{\"id\":\"$id\",\"name\":\"$name\",\"callbackURLs\":[\"$callback\"]}"
      # Pocket ID can generate a secret on create; drop it so only the .env secret is valid
      for sid in $(secret_ids "$id"); do
        api -f -o /dev/null -X DELETE "$BASE/oidc/clients/$id/secrets/$sid"
      done
      echo "$id: client created"
      ;;
    *)
      echo "$id: Pocket ID answered $status" >&2
      exit 1
      ;;
  esac

  # Pocket ID keeps the first 4 characters of each secret in clear text
  prefix=${secret:0:4}
  if api -f "$BASE/oidc/clients/$id/secrets" | grep -q "\"prefix\":\"$prefix\""; then
    echo "$id: secret already registered"
  else
    api -f -o /dev/null -X POST "$BASE/oidc/clients/$id/secrets" -d "{\"secret\":\"$secret\"}"
    echo "$id: secret added"
  fi
}

TINYAUTH_ID=$(raw_value TINYAUTH_OIDC_CLIENT_ID "$ENV_FILE")
register "${TINYAUTH_ID:-tinyauth}" "Tinyauth" \
  "https://tinyauth.$DOMAIN_NAME/api/oauth/callback/pocketid" \
  "$(raw_value TINYAUTH_OIDC_CLIENT_SECRET "$ENV_FILE")"
