# AGENTS.md

## What this repo is

A personal homelab: one Docker Compose stack that runs media, network, automation, AI and
tooling services on a single always-on server. It is deployed by running `docker compose up -d`
from the repo root on that server, so every change here is a change to a live system.

There is no build step and no application code. The deliverable is YAML that a human reads and
Docker consumes, and `tests/validate-compose.sh` is the only test. Optimise for files that are boring, consistent and easy to
diff against their neighbours.

## Layout

- `docker-compose.yaml` — the entry point. Holds nothing but `include:` (one line per app,
  grouped by category with a `# Category` comment), the shared `networks:`, and the `myMedia`
  volume that binds `${MEDIA_DIR}` into the *arr/media containers.
- `docker-compose.ports.yaml` — optional overlay holding nothing but a `ports:` block per
  service, in the same category order. Loaded only when `COMPOSE_FILE` names it, so the
  default stack publishes no web UI on the host.
- `apps/<category>/<app>.yaml` — one file per app. Categories: `ai`, `auth`, `automation`, `media`,
  `network`, `tools`. Each file is self-contained: its services, its named volumes and, if it
  needs one, its own private network.
- `apps/config/` — configuration mounted into containers (traefik static config and dynamic
  rules, Homepage, Configarr, qBittorrent). Anything a container reads from disk lives here, not in `/data`.
- `.env.example`, `.env.gluetun.example` — tracked templates. The real `.env`, `.env.gluetun`
  and the provider-specific `.env.gluetun.*` files are gitignored and hold the actual secrets.
- `scripts/setup-env.sh` — first-run bootstrap: creates `.env` from the template, generates the random
  secrets, detects host values (LAN IP/CIDR, timezone, PUID/PGID), scaffolds `.env.gluetun`.
  Idempotent. Keep it in sync when you add variables (see "Adding an app").
- `scripts/pocket-id-clients.sh` — run on the server once Pocket ID is up: registers the OIDC clients in
  Pocket ID with the IDs and secrets from `.env`. An app that signs in through Pocket ID gets a
  `register` line here and a generated secret in `scripts/setup-env.sh`.
- `README.md` — a per-service catalogue with ports and profiles, kept in sync with `apps/`, and
  the Mermaid architecture diagram under "Architecture" (see "Architecture diagram").
- `tests/validate-compose.sh`: renders the stack without `.env` (with and without the ports overlay)
  and checks which services each profile starts.

## Conventions

### Compose files

- Start every app file with the `yaml-language-server` schema comment; the rest of the file
  should not need comments.
- Always set `container_name` — traefik and the `myMedia` mounts all key off it.
- `restart: ${UNIVERSAL_RESTART_POLICY:-unless-stopped}` on every service (traefik itself is
  the exception, it uses `always`; run-once helpers such as `configarr` use `"no"`).
- Follow `restart:` with the same `logging:` block every service uses (`json-file`, `max-size: 10m`,
  `max-file: "3"`). Compose has no stack-wide default, so each service carries it.
- Give a service a memory limit right after `profiles:`, as `deploy.resources.limits.memory:
  ${<APP>_MEMORY_LIMIT:-<default>}`, with a default comfortably above its normal use. Leave it off
  services whose memory grows with their workload (databases, caches, AI, media servers, browsers,
  torrent clients). Don't add the variable to `.env.example`; add the service to the table under
  "Memory limits" in the README.
- Use map syntax for `environment:` (`KEY: value`).
- Declare named volumes in a `volumes:` block at the bottom of the same app file, prefixed with
  the app name (`radarr_data`, `tracearr_db_data`).
- An app with built-in scheduled backups mounts `${BACKUP_DIR:?set BACKUP_DIR in .env}/<app>` over
  its default backup folder. `BACKUP_DIR` is the single backup root; the host OS syncs it one way
  to a cloud provider, so nothing in the stack uploads backups and no backup container is needed.
  When adding such an app:
  - add `<app>` to the backup directory loop in `scripts/setup-env.sh` and a row to the table under
    "7. Backups" in the README;
  - check which uid the image writes as. `PUID`-aware images and root work with the directory
    `scripts/setup-env.sh` creates; a fixed non-root uid (Tracearr's 1001) needs a `sudo chown -R <uid>`
    step in `scripts/setup-env.sh` and the README, like Tracearr's.

### Profiles

`COMPOSE_PROFILES` in `.env` selects what runs; the default is `default`. Compose profiles do not
nest, so every service lists, in order: its app profile (the file name, shared by every service in
that file), its category profiles, then the groups it belongs to:

- `basic` — the everyday stack: media, arrs, vpn, tools, network
- `default` — `basic` plus traefik and tailscale
- `full` — every long-running service, always included
- `media` / `arrs` / `plex` / `jellyfin` — media servers, and the *arr apps that manage them
- `vpn` — anything that must sit behind gluetun
- `ai`, `auth`, `automation`, `homarr`, `network`, `pihole`, `tailscale`, `tools`, `traefik` — the
  remaining groupings

Every app profile must start on its own. Mark a `depends_on` entry `required: false` when the app
works without it; when it cannot (qBittorrent needs gluetun's network), add the app's profile to the
dependency instead.

A new service goes in `basic` and `default` too, unless it is heavy, needs extra setup, or changes
how the host behaves; those stay in `full` only.

An on-demand tool (`configarr`) lists only its app profile, not even `full`, so `up -d` never starts
it. `docker compose run --rm <app>` still works, because naming a service enables its profiles.

### Networking

- `traefik` is the shared front network; put the user-facing service on it.
- `vpn` belongs to gluetun. Containers that must be tunnelled use `network_mode: service:gluetun`
  and publish their ports on the gluetun service instead of their own.
- An app that ships its own database or cache declares a private network inside its own file and
  keeps the supporting containers off `traefik`.
- A web UI's host port goes in `docker-compose.ports.yaml`, not in the app file, as
  `${APP_PORT:-<default>}:<container-port>/tcp`. Check the default is free — Open-WebUI
  already holds 3000, Homepage 3002, Homarr 7575, and the *arr apps their usual ports. Keep a port in the app
  file only when it cannot work behind Traefik anyway (Traefik's own 80/443, Pi-hole's DNS,
  Plex, the torrent port).

### Labels

- Traefik runs with `exposedByDefault: false`, so a service is only routed if it sets
  `traefik.enable: true`. The router hostname comes from the container name plus
  `${DOMAIN_NAME}`, so a plain `traefik.http.services.<app>.loadbalancer.server.port` is usually
  all the extra configuration needed.
- `gangplank.forward: "<port>/<proto>"` marks ports that should be forwarded on the router.
- `homelab.public: true` plus `traefik.http.routers.<app>.entrypoints: websecure,public` also
  serves the app at `<app>.${PUBLIC_DOMAIN}` from the internet. Only add it to an app with its own
  login, and only when asked.
- An app with no login of its own gets
  `traefik.http.routers.<app>.middlewares: ${TINYAUTH_ENABLED:+tinyauth@docker}`, so Tinyauth
  protects it whenever `TINYAUTH_ENABLED` is set.

### Secrets and environment

- Never put a credential in a compose file. Reference `${VAR}` and add it to `.env.example`
  with a short inline hint about how to generate it.
- Never read from or write to `.env`, `.env.gluetun` or `.env.gluetun.*` — they are the user's
  live secrets. Templates only.
- Give a variable a sensible inline default (`${VAR:-default}`) whenever one exists, and leave
  it commented out in `.env.example` to show it is optional.

## Adding an app

1. Write `apps/<category>/<app>.yaml` following the conventions above.
2. Add the `include:` line to `docker-compose.yaml` under the right category, and the
   `ports:` block to `docker-compose.ports.yaml` if the app has a web UI.
3. Add any new variables to `.env.example`. If a variable is a random secret (API key,
   encryption/JWT secret, password) or derivable from the host (an IP, CIDR, id, timezone),
   also wire it into `scripts/setup-env.sh` — the `GEN` array for random values, the `fill_detected`
   block for host values — so a fresh `.env` comes up ready to launch.
4. Add a `#### [App](<project website>) ([definition](apps/<category>/<app>.yaml))` entry to the
   README service list, with the one-line description, ports and profiles.
5. Prefer the upstream project's own recommended compose file as the starting point, then strip
   it to the minimum that works here: drop settings that only restate image defaults, and keep
   the ones that are load-bearing.
6. Add `check` lines for the app's profiles to `tests/validate-compose.sh` and run it.
7. Add the app to the README architecture diagram (see below).

## Architecture diagram

The Mermaid chart under "Architecture" in the README draws every service in `docker-compose.yaml`.
Update it in the same change whenever you add, remove or rename a service, or change how services
connect (`depends_on`, `network_mode: service:gluetun`, Tinyauth middleware, Pocket ID/OIDC,
Cloudflare, Tailscale).

- Put the app in its category group, as an image node with its [selfh.st](https://selfh.st/icons/)
  icon (`https://raw.githubusercontent.com/selfhst/icons/main/png/<name>.png`). GitHub's Mermaid
  viewer only loads images from a few hosts such as `raw.githubusercontent.com`, and raw serves SVG
  as plain text, so other CDNs or SVG icons break the whole chart. An app without an icon is a plain
  text node.
- Traefik and Auth arrows point at whole groups, not at single apps. Draw an app-to-app arrow only
  for a real relationship, with a short label.
- The chart uses Mermaid's default (dagre) layout, because GitHub's viewer does not ship ELK. Two
  things drive it:
  - Edge direction sets the rows: a target always lands below its source. Write an edge from the
    upper node, as in `gluetun -.-|"via VPN"| qbit`; drawn the other way it drags Gluetun to the
    bottom of the chart.
  - A group without `direction` runs opposite to its parent, so in a `TB` chart it runs `LR` and
    unlinked apps stack in a column. Give a group `direction TB` to put unlinked apps in one row
    (Automation, Tools) or a linked pair one above the other (Open WebUI and Ollama).
- Two linked apps that must sit side by side (Tinyauth and Pocket ID) go in an unbordered inner
  subgraph with `direction LR`, with the outside edges pointing at the outer group.
- Render the chart with GitHub's Mermaid version and look at it before committing.

## Verifying

Run the test suite after any change to the compose files, `.env.example` or profiles:

```bash
tests/validate-compose.sh
```

It ignores `.env` and exports placeholder values for the variables the stack cannot render without,
then renders every included file (catching schema errors, bad references and unresolved variables)
and asserts which services each profile starts. Keep it in step with the stack:

- a new required variable (`${VAR:?...}` or no default) gets a placeholder `export` at the top;
- a new app, profile or group gets `check present` / `check absent` lines for where it should and
  should not start.

Also render the stack with the real `.env`, plain and with the ports overlay:

```bash
docker compose config --quiet
```

```bash
COMPOSE_FILE=docker-compose.yaml:docker-compose.ports.yaml docker compose config --quiet
```

When a change touches README headings or links, check every link you changed or that points at a
changed heading:

- an in-page link (`#anchor`) must match a heading. GitHub builds the anchor from the visible
  heading text: lowercase, punctuation dropped, spaces turned into hyphens. So
  `#### [Sonarr](https://sonarr.tv) ([definition](apps/media/sonarr.yaml))` becomes
  `#sonarr-definition`, and renaming a heading breaks every link to it;
- a relative link must point at a file that exists;
- an external link must still load.

Do not run `docker compose up`, `down`, `pull` or `restart` unless explicitly asked. The stack
is live, and pulling or recreating a container is a production action, not a verification step.
