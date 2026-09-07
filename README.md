# My Homelab Docker setup

This is my entire homelab setup running on any Docker Compose enabled machine offering useful home automation, media management and networking tools, as well as some simple AI setup for capable machines.

Feel free to fork it and use it on your own machine and customize it if needed.

> **Support this project!**
>
> If you find this project useful, consider sponsoring me on [GitHub Sponsors](https://github.com/sponsors/IonBazan) to help support ongoing development and maintenance. Your support is greatly appreciated!

## Key principles

### Simplicity

Each service resides in their own YAML file and is included in the main `docker-compose.yaml` for better isolation and maintainability.
While Traefik is currently enabled, accessing services via their exposed ports is preferred over custom subdomains with SSL, although it is possible to use them too.

### Ease of customization

#### Profiles
You can choose the services to deploy in your setup using different [Docker Compose profiles](https://docs.docker.com/compose/how-tos/profiles/) (see `COMPOSE_PROFILES` environment variable). Following profiles are supported:

- `media` - Media tools - all the *arrs, Jellyfin
- `automation` - Home automation tools
- `vpn` - Gluetun and qBittorrent
- `all` - All above

Additionally, following are not included in `all` as they are quite optional:
- `traefik` - Traefik
- `pihole` - PiHole
- `ai` - AI tools like Ollama and Open-WebUI

#### Environment variables

Most ports are configurable via _optional_ environment variables. Check out individual services config to learn more.
Tokens, subdomains and other configuration can be found in `.env.example`.

You can also customize default restart policy using `UNIVERSAL_RESTART_POLICY` variable (defaults to `unless-stopped`).

### Portability

Easy to set up - simply copy the files to any machine, change `.env` parameters and run `docker-compose up -d`. No complex makefiles, Ansible or bash scripts. Works on most platforms and architectures out of the box.

## Setup

### Prerequisites

- A Linux host with Docker Engine and the Compose plugin (`docker compose version` works).
- A single media directory containing `Movies/`, `Shows/` and `Downloads/` subdirectories (media/`arrs` profiles only).
- A domain on Cloudflare, if you want Traefik + HTTPS. You'll add `A` records for it pointing at the server's LAN IP — see [Networking](#networking).

### 1. Get the files and create the env files

```bash
git clone git@github.com:IonBazan/homelab.git
cd homelab
cp .env.example .env
cp .env.gluetun.example .env.gluetun.nordvpn      # or .env.gluetun.wireguard
ln -sf .env.gluetun.nordvpn .env.gluetun          # pick the active VPN config
```

`.env`, `.env.gluetun` and every `.env.gluetun.*` file are gitignored — they hold your real secrets. `.env.example` / `.env.gluetun.example` are the tracked templates.

### 2. Fill in `.env`

Work top to bottom; anything left commented is optional and shown at its default.

| Variable | Needed for | Where to get / how to set it |
|---|---|---|
| `DOMAIN_NAME` | Traefik, DNS | The domain you route services under, e.g. `homelab.example.com`. Every service is published at `<name>.${DOMAIN_NAME}`. |
| `TZ` | all | IANA name, e.g. `Europe/Warsaw` ([list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)). |
| `PUID` / `PGID` | media apps | `id -u` / `id -g` for the user that owns `MEDIA_DIR`. |
| `MEDIA_DIR` | media apps | Absolute path to the media root (holds `Movies/`, `Shows/`, `Downloads/`). Compose does **not** expand `~`. |
| `COMPOSE_PROFILES` | service selection | Comma-separated (see [Profiles](#profiles)). `all` omits `traefik`, `pihole`, `ai` — add them explicitly, e.g. `all,traefik`. |
| `PHYSICAL_SERVER_IP` | Plex, Tailscale, DNS records | Host LAN IP: `ip route get 1 \| awk '{print $7}'`. |
| `PHYSICAL_SERVER_NETWORK` | Tailscale subnet router | Your LAN CIDR, e.g. `192.168.1.0/24`. |
| `PUBLIC_DOMAIN` | Plex remote access | A public hostname tracking your home IP — see [Networking](#networking). |
| `PLEX_CLAIM` | Plex first run | Fresh token from <https://www.plex.tv/claim> (valid ~4 min); can be blanked after first start. |
| `TAILSCALE_TOKEN` | Tailscale | Tailscale admin → **Settings → Keys → Generate auth key**. Mark it *Reusable* + *Pre-approved* to skip manual route approval. |
| `CF_DNS_API_TOKEN` | Traefik HTTPS | Cloudflare → **My Profile → API Tokens → Create Token → "Edit zone DNS"**, scoped to your zone (`Zone:DNS:Edit` + `Zone:Zone:Read`). |
| `CF_API_EMAIL` | Traefik HTTPS | Your Cloudflare account email (used as the Let's Encrypt account email). |
| `HOMARR_SECRET_ENCRYPTION_KEY` | Homarr | `openssl rand -hex 32` |
| `TRACEARR_JWT_SECRET` / `TRACEARR_COOKIE_SECRET` | Tracearr | `openssl rand -hex 32` each |
| `SONARR_API_KEY` / `RADARR_API_KEY` / `PROWLARR_API_KEY` | Configarr | `openssl rand -hex 16` each. Leave blank to let each app self-generate (Configarr then won't run). |
| `RENDER_GID` | Plex HW transcode | `getent group render \| cut -d: -f3` on the host. |

### 3. Fill in `.env.gluetun` (only with the `vpn` profile)

Edit the file you symlinked and uncomment **one** provider block:

- **NordVPN** — dashboard → *NordVPN manual setup* → copy the **service credentials** into `OPENVPN_USER` / `OPENVPN_PASSWORD`.
- **Custom WireGuard** — copy the values from your provider's `.conf` (`WIREGUARD_PRIVATE_KEY`, `WIREGUARD_ADDRESSES`, peer `WIREGUARD_PUBLIC_KEY`, `VPN_ENDPOINT_IP`, `VPN_ENDPOINT_PORT`).

Set `FIREWALL_OUTBOUND_SUBNETS` to your LAN CIDR so the qBittorrent WebUI stays reachable while the tunnel is up.

### 4. Create the media layout

```bash
mkdir -p /path/to/media/{Movies,Shows,Downloads}   # same path as MEDIA_DIR
```

### 5. Launch

```bash
docker compose up -d
```

With the `traefik` profile on, first start issues one wildcard certificate over the Cloudflare DNS-01 challenge — follow it with `docker compose logs -f traefik`. Re-run the same command after any `.env` change.

`configarr` runs once and exits; the *arr apps need to have generated their databases first, so re-run it after the initial start:

```bash
docker compose run --rm configarr
```

## Networking

### DNS — one Cloudflare record, home and away

Create the records in Cloudflare pointing at the server's **LAN IP**, **DNS-only** (grey cloud — Cloudflare's proxy can't reach a private address, and the traffic should stay local anyway):

```
homelab.example.com     A   192.168.1.10
*.homelab.example.com   A   192.168.1.10
```

- **At home** — the name resolves to `192.168.1.10` and you connect straight over the LAN.
- **Away** — connect to your tailnet; the [Tailscale](#tailscale) container advertises `PHYSICAL_SERVER_NETWORK` as a subnet route, so `192.168.1.10` is reachable through it. The *same* public record works, so there is no split-horizon DNS and no local DNS server to run.

### TLS

Traefik (profile `traefik`) obtains one wildcard certificate for `${DOMAIN_NAME}` + `*.${DOMAIN_NAME}` through the Cloudflare **DNS-01** challenge. That uses only the API token — the record never has to be publicly reachable — so pointing it at a LAN IP is fine. Routers come from the container name: a service is live at `https://<container>.${DOMAIN_NAME}` as soon as it has `traefik.enable: true`. Dashboard: `https://${TRAEFIK_SUBDOMAIN:-traefik}.${DOMAIN_NAME}/dashboard/` (trailing slash required).

### Tailscale subnet router

The single advertised route (`PHYSICAL_SERVER_NETWORK`) is what makes those LAN-IP records resolve correctly from anywhere on the tailnet. Approve the route and enable host IP-forwarding — see the [Tailscale](#tailscale) service notes.

### Public internet (optional)

Only for services that need a real public endpoint (Plex remote access): set `PUBLIC_DOMAIN` to a hostname that follows your home IP, keep DDNS Updater (profile `all`) running — providers go in `apps/config/ddns-updater/config.json` ([format](https://github.com/qdm12/ddns-updater#configuration)) — and forward the port on your router (Plex `32400/tcp`; Gangplank can automate UPnP forwards from the `gangplank.forward` labels). Plex advertises both its LAN and `PUBLIC_DOMAIN` endpoints via `ADVERTISE_IP`. Everything else stays private to LAN + tailnet.

### Pi-hole (optional)

Not part of routing — just a network-wide ad blocker (profile `pihole`, not in `all`). If you do run it and point clients at it, it can serve the `*.${DOMAIN_NAME}` → `PHYSICAL_SERVER_IP` mapping locally instead of the Cloudflare records.

## Application list

### AI

#### [Ollama](apps/ai/ollama.yaml)
A local AI model runner for LLMs, providing an API for running and managing models on your own hardware.
- **Ports:** 11434:11434/tcp
- **Profiles:** `ai`, `all`

#### [Open-WebUI](apps/ai/open-webui.yaml)
A web-based user interface for interacting with local LLMs, designed to work with Ollama and similar backends.
- **Ports:** 3000:8080/tcp
- **Profiles:** `ai`, `all`

### Automation

#### [Home Assistant](apps/automation/homeassistant.yaml)
Open-source home automation platform running on your local network, supporting a wide range of smart devices.
- **Ports:** host (8123 by default)
- **Profiles:** `automation`, `all`

#### [Homebridge](apps/automation/homebridge.yaml)
Bridges non-HomeKit devices to Apple HomeKit, enabling control of a wide range of smart home devices from Apple devices.
- **Ports:** host (8581 by default)
- **Profiles:** `automation`, `all`

### Media

#### [Jellyfin](apps/media/jellyfin.yaml)
A free software media system that puts you in control of managing and streaming your media.
- **Ports:** 8096:8096/tcp, 8920:8920/tcp
- **Profiles:** `media`, `all`

#### [Plex](apps/media/plex.yaml)
A popular media server for streaming your personal media collection to any device.
- **Ports:** 32400:32400/tcp (configurable via PLEX_PORT), 8324:8324/tcp, 32469:32469/tcp, 1900:1900/udp, 32410:32410/udp, 32412:32412/udp, 32413:32413/udp, 32414:32414/udp
- **Profiles:** `media`, `all`

Passes the host's `/dev/dri` through for Intel QuickSync / VAAPI hardware transcoding. Set
`RENDER_GID` in `.env` to the host's `render` group id (`getent group render | cut -d: -f3`),
then enable *Settings > Transcoder > Use hardware acceleration when available* in Plex — this
needs an active Plex Pass. Transcodes are written to `/transcode` (`PLEX_TRANSCODE_DIR`,
defaults to `/tmp`) instead of the config volume.

#### [Prowlarr](apps/media/prowlarr.yaml)
An indexer manager/proxy for *arr applications, supporting Usenet and BitTorrent indexers.
- **Ports:** 9696:9696/tcp (configurable via PROWLARR_PORT)
- **Profiles:** `media`, `arrs`, `all`

#### [qBittorrent](apps/media/qbittorrent.yaml)
A feature-rich and open-source BitTorrent client with a web UI, running behind a VPN for privacy.
- **Ports:** published on the `gluetun` container — `${QBITTORRENT_PORT:-8081}/tcp` (WebUI), `${TORRENT_PORT:-6881}/tcp+udp` (torrents)
- **Profiles:** `vpn`, `all`
- **Traefik:** its router is defined on the `gluetun` service (qBittorrent shares gluetun's network namespace).

Ships a seed [`apps/config/qbittorrent/qBittorrent.conf`](apps/config/qbittorrent/qBittorrent.conf)
mounted over the live config so the container starts with the legal notice already accepted,
downloads saved to `/media/Downloads`, reverse-proxy-friendly WebUI settings and LAN auth
bypass. qBittorrent rewrites this file as you change settings in the UI. The torrent listen
port is left unset so qBittorrent picks and persists one on first run — set it in the UI to
match `TORRENT_PORT` if you need inbound connections through the VPN.

#### [Radarr](apps/media/radarr.yaml)
A movie collection manager for Usenet and BitTorrent users, automating downloads and organization.
- **Ports:** 7878:7878/tcp (configurable via RADARR_PORT)
- **Profiles:** `media`, `arrs`, `all`

#### [Bazarr](apps/media/bazarr.yaml)
A companion app for Radarr and Sonarr that manages and downloads subtitles for movies and TV series.
- **Ports:** 6767:6767/tcp (configurable via BAZARR_PORT)
- **Profiles:** `media`, `arrs`, `all`

#### [Tracearr](apps/media/tracearr.yaml)
A self-hosted playback tracker and analytics dashboard for Plex, Jellyfin and Emby. Ships with its own TimescaleDB and Redis containers on a private `tracearr` network.
- **Ports:** 3001:3000/tcp (configurable via TRACEARR_PORT)
- **Profiles:** `media`, `all`

Requires `TRACEARR_JWT_SECRET` and `TRACEARR_COOKIE_SECRET` in `.env` (`openssl rand -hex 32` each).

#### [Sonarr](apps/media/sonarr.yaml)
A TV series collection manager for Usenet and BitTorrent users, automating downloads and organization.
- **Ports:** 8989:8989/tcp (configurable via SONARR_PORT)
- **Profiles:** `media`, `arrs`, `all`

Set `SONARR_API_KEY` in `.env` (`openssl rand -hex 16`) to pin the API key via the
`SONARR__AUTH__APIKEY` environment variable instead of letting Sonarr generate one. Radarr
has the same `RADARR_API_KEY` / `RADARR__AUTH__APIKEY` pair.

#### [Configarr](apps/media/configarr.yaml)
Syncs [TRaSH-Guides](https://trash-guides.info/) custom formats, quality definitions and quality
profiles into Sonarr and Radarr, driven by [`apps/config/configarr/config.yml`](apps/config/configarr/config.yml).
- **Ports:** none (run-once container)
- **Profiles:** `media`, `arrs`, `all`

Requires `SONARR_API_KEY` and `RADARR_API_KEY` in `.env`; it reads them via `!env` and reaches
each app over the `traefik` network. It also manages the root folders, pointing Sonarr at
`/media/Shows` and Radarr at `/media/Movies` (the `Shows` / `Movies` dirs under `MEDIA_DIR`).
It runs once and exits on `docker compose up -d`; re-run it any time with:

```bash
docker compose run --rm configarr
```

### Network

#### [DDNS Updater](apps/network/ddns-updater.yaml)
Keeps your Dynamic DNS records up to date with your current public IP address.
- **Ports:** 8001:8000/tcp (configurable via DDNS_UPDATER_PORT)
- **Profiles:** `all`

#### [Gangplank](apps/network/gangplank.yaml)
A simple Docker port forwarder and helper for exposing services.
- **Ports:** host
- **Profiles:** `all`

#### [Gluetun](apps/network/gluetun.yaml)
VPN client container to route traffic of other containers (qBittorrent) through a secure VPN tunnel.
- **Ports:** 8081/tcp (qBittorrent WebUI, configurable via `QBITTORRENT_PORT`), 6881/tcp+udp (torrents, configurable via `TORRENT_PORT`)
- **Profiles:** `vpn`, `all`

VPN provider config is kept separate from the main `.env` so credentials are never in the compose files.
Copy `.env.gluetun.example` to create a provider-specific file, fill in your credentials, then symlink it as the active config:

```bash
cp .env.gluetun.example .env.gluetun.nordvpn    # or .env.gluetun.wireguard
# edit the file and fill in credentials
ln -sf .env.gluetun.nordvpn .env.gluetun         # make it active
docker compose up -d --force-recreate gluetun qbittorrent
```

To switch providers, point the symlink at a different file and recreate the containers:

```bash
ln -sf .env.gluetun.wireguard .env.gluetun
docker compose up -d --force-recreate gluetun qbittorrent
```

#### [Pi-hole](apps/network/pihole.yaml)
Optional network-wide ad blocker and DNS sinkhole. Not required for service routing — see
[Networking](#networking). When enabled it also publishes `address=/${DOMAIN_NAME}/${PHYSICAL_SERVER_IP}`,
a local alternative to the Cloudflare `*.${DOMAIN_NAME}` records.
- **Ports:** 53:53/tcp, 53:53/udp, 81:80/tcp
- **Profiles:** `pihole` (not in `all`)

#### [Tailscale](apps/network/tailscale.yaml)
Zero-config VPN to connect your devices and networks securely using WireGuard.
- **Ports:** host
- **Profiles:** (not specified)

Runs as a subnet router: `TS_ROUTES` advertises `PHYSICAL_SERVER_NETWORK` so remote tailnet
devices reach LAN hosts (including `PHYSICAL_SERVER_IP`) by their local IP through this node.
After first start, approve the route under *Machines > this host > Route settings* in the
[Tailscale admin console](https://login.tailscale.com/admin/machines) (or pre-approve it with an
`autoApprovers` ACL). The host also needs IP forwarding enabled:

```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
```

#### [Traefik](apps/network/traefik.yaml)
Modern reverse proxy and load balancer for microservices and web applications.
- **Ports:** 80:80/tcp, 443:443/tcp
- **Profiles:** `traefik`

Routes any container with `traefik.enable: true` at `<container>.${DOMAIN_NAME}` (see
[Networking](#networking)). TLS is a single wildcard cert (`${DOMAIN_NAME}` + `*.${DOMAIN_NAME}`)
via the Cloudflare DNS-01 challenge, configured as `tls.stores.default.defaultgeneratedcert`
on the Traefik container's own labels so no per-service certificate is ever requested. The
cert store is the `traefik_certs` volume; delete `acme.json` inside it to force re-issue.
Needs `CF_DNS_API_TOKEN` (and `CF_API_EMAIL`) in `.env`.

### Tools

#### [Dockpeek](apps/tools/dockpeek.yaml)
A web UI for monitoring and managing Docker containers.
- **Ports:** 8000:8000/tcp (configurable via DOCKPEEK_PORT)
- **Profiles:** (not specified)

#### [Homarr](apps/tools/homarr.yaml)
A modern, feature-rich dashboard for self-hosted services with Docker integration.
- **Ports:** 7575:7575/tcp (configurable via HOMARR_PORT)
- **Profiles:** (not specified)

## Contributing

As this is my personal homelab setup, I may not accept any contributions but feel free to fork this repository and use it for your own homelab.
