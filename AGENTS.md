# AGENTS.md

## What this repo is

A personal homelab: one Docker Compose stack that runs media, network, automation, AI and
tooling services on a single always-on server. It is deployed by running `docker compose up -d`
from the repo root on that server, so every change here is a change to a live system.

There is no build step, no application code and no test suite — the deliverable is YAML that a
human reads and Docker consumes. Optimise for files that are boring, consistent and easy to
diff against their neighbours.

## Layout

- `docker-compose.yaml` — the entry point. Holds nothing but `include:` (one line per app,
  grouped by category with a `# Category` comment), the shared `networks:`, and the `myMedia`
  volume that binds `${MEDIA_DIR}` into the *arr/media containers.
- `apps/<category>/<app>.yaml` — one file per app. Categories: `ai`, `automation`, `media`,
  `network`, `tools`. Each file is self-contained: its services, its named volumes and, if it
  needs one, its own private network.
- `apps/config/` — configuration mounted into containers (traefik static config and dynamic
  rules, pihole entrypoint). Anything a container reads from disk lives here, not in `/data`.
- `.env.example`, `.env.gluetun.example` — tracked templates. The real `.env`, `.env.gluetun`
  and the provider-specific `.env.gluetun.*` files are gitignored and hold the actual secrets.
- `README.md` — a per-service catalogue with ports and profiles, kept in sync with `apps/`.

## Conventions

### Compose files

- Start every app file with the `yaml-language-server` schema comment; the rest of the file
  should not need comments.
- Always set `container_name` — traefik, dockpeek and the `myMedia` mounts all key off it.
- `restart: ${UNIVERSAL_RESTART_POLICY:-unless-stopped}` on every service (traefik itself is
  the exception, it uses `always`).
- Use map syntax for `environment:` (`KEY: value`). The list form in `traefik.yaml` and
  `dockpeek.yaml` predates the convention; don't copy it into new files.
- Declare named volumes in a `volumes:` block at the bottom of the same app file, prefixed with
  the app name (`radarr_data`, `tracearr_db_data`).

### Profiles

`COMPOSE_PROFILES` in `.env` selects what runs; the default is `all`. Give every service the
profiles it plausibly belongs to, always including `all`:

- `media` / `arrs` — media servers, and the *arr apps that manage them
- `vpn` — anything that must sit behind gluetun
- `ai`, `automation`, `tools`, `traefik`, `pihole` — the remaining groupings

### Networking

- `traefik` is the shared front network; put the user-facing service on it.
- `vpn` belongs to gluetun. Containers that must be tunnelled use `network_mode: service:gluetun`
  and publish their ports on the gluetun service instead of their own.
- An app that ships its own database or cache declares a private network inside its own file and
  keeps the supporting containers off `traefik`.
- Publish ports as `${APP_PORT:-<default>}:<container-port>/tcp`. Check the default is free —
  Homepage already holds 3000, OpenList 5244/5245, and the *arr apps their usual ports.

### Labels

- Traefik runs with `exposedByDefault: false`, so a service is only routed if it sets
  `traefik.enable: true`. The router hostname comes from the container name plus
  `${DOMAIN_NAME}`, so a plain `traefik.http.services.<app>.loadbalancer.server.port` is usually
  all the extra configuration needed.
- `dockpeek.tags: <category>` on everything; add `dockpeek.ports` when the published port isn't
  what dockpeek should link to.
- `homepage.*` labels are optional and only present on a few services.
- `gangplank.forward: "<port>/<proto>"` marks ports that should be forwarded on the router.

### Secrets and environment

- Never put a credential in a compose file. Reference `${VAR}` and add it to `.env.example`
  with a short inline hint about how to generate it.
- Never read from or write to `.env`, `.env.gluetun` or `.env.gluetun.*` — they are the user's
  live secrets. Templates only.
- Give a variable a sensible inline default (`${VAR:-default}`) whenever one exists, and leave
  it commented out in `.env.example` to show it is optional.

## Adding an app

1. Write `apps/<category>/<app>.yaml` following the conventions above.
2. Add the `include:` line to `docker-compose.yaml` under the right category.
3. Add any new variables to `.env.example`.
4. Add a `#### [App](apps/<category>/<app>.yaml)` entry to the README service list, with the
   one-line description, ports and profiles.
5. Prefer the upstream project's own recommended compose file as the starting point, then strip
   it to the minimum that works here: drop settings that only restate image defaults, and keep
   the ones that are load-bearing.

## Verifying

```bash
docker compose config --quiet
```

That renders every included file with the current `.env` and is the only check available — it
catches schema errors, bad references and unresolved variables. Run it after any YAML change.

Do not run `docker compose up`, `down`, `pull` or `restart` unless explicitly asked. The stack
is live, and pulling or recreating a container is a production action, not a verification step.
