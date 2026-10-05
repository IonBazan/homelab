# My Homelab Docker setup

My entire homelab setup, running on any machine with Docker Compose. It covers home automation,
media management and networking tools, plus a small AI stack for capable hardware.

Feel free to fork it, adjust the `.env` values and run it on your own machine.

> **Support this project!**
>
> If you find this project useful, consider sponsoring me on [GitHub Sponsors](https://github.com/sponsors/IonBazan) to help support ongoing development and maintenance. Your support is greatly appreciated!

## Key principles

### Simplicity

Each service has its own YAML file, included from `docker-compose.yaml`. Host ports live in one
optional overlay, `docker-compose.ports.yaml`, so you can run the stack behind Traefik only or also
publish every UI on the LAN. See [Host ports](#host-ports).

### Ease of customization

#### Environment variables

Everything you can configure is in `.env.example`: tokens, subdomains, paths and, under
`HOST PORTS` at the bottom, the optional host ports.

The default restart policy is `unless-stopped` and can be changed with `UNIVERSAL_RESTART_POLICY`.

#### Host ports

By default no web UI is published on the host. You reach the apps through Traefik at
`https://<container>.${DOMAIN_NAME}` (profile `traefik`) or over Tailscale. The optional
`docker-compose.ports.yaml` overlay adds a `ports:` block to each of those services, so they are also
reachable at `http://<server ip>:<port>`. To load it, uncomment `COMPOSE_FILE` in `.env`:

```dotenv
COMPOSE_FILE=docker-compose.yaml:docker-compose.ports.yaml
```

Without Traefik you need the overlay, or there is no way in. With Traefik it is optional.
Containers talk to each other over the Docker networks either way, so routing, the Homepage widgets
and Configarr work in both setups.

Some ports cannot go through Traefik, so they are always published: Traefik's own `80`, `443` and
`8443` (`TRAEFIK_PUBLIC_PORT`), Pi-hole's DNS on `53`, Plex's `32400` and its discovery ports, and
gluetun's `TORRENT_PORT`.

### Portability

Copy the files to any Linux machine with Docker, run `scripts/setup-env.sh`, fill in the few values
it cannot guess, and run `docker compose up -d`. There are no makefiles and no Ansible. The two
scripts in `scripts/` are optional helpers for the first run.

Several apps need Linux features that Docker Desktop on macOS or Windows does not provide: host
networking (Home Assistant, Homebridge, Tailscale, Gangplank), `/run/dbus`, `/dev/net/tun` and
Plex's `/dev/dri`. On a host without an Intel or AMD GPU, remove the `devices` and `group_add`
lines from [`plex.yaml`](apps/media/plex.yaml), otherwise Plex does not start.

## Architecture

Cloudflare points `${DOMAIN_NAME}` and `*.${DOMAIN_NAME}` at the server's LAN IP. At home you reach
every web UI through Traefik. Away from home, Tailscale's subnet route gets you to the same address.
Traefik gets its certificates through Cloudflare's DNS challenge.

DDNS Updater keeps a second Cloudflare hostname, `PUBLIC_DOMAIN`, pointed at your public IP. Plex
remote access and the apps that opt in (Tracearr) use it. With `TINYAUTH_ENABLED` set, Tinyauth adds
a Pocket ID login in front of the *arr apps and a few tools. qBittorrent shares Gluetun's network,
so its traffic goes through the VPN. Icons come from [selfh.st/icons](https://selfh.st/icons/).

```mermaid
---
config:
  flowchart:
    nodeSpacing: 30
    rankSpacing: 40
---
flowchart TB
    you(["👤 Browser or mobile app"])
    internet(("🌐"))
    cloudflare@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/cloudflare.png", label: "Cloudflare", pos: "b", w: 40, h: 40, constraint: "on" }

    subgraph net["Network"]
        direction LR
        tailscale@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/tailscale.png", label: "Tailscale", pos: "b", w: 32, h: 32, constraint: "on" }
        gluetun@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/gluetun.png", label: "Gluetun", pos: "b", w: 32, h: 32, constraint: "on" }
        ddns@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/ddns-updater.png", label: "DDNS Updater", pos: "b", w: 32, h: 32, constraint: "on" }
        gangplank@{ img: "https://raw.githubusercontent.com/IonBazan/gangplank/refs/heads/main/logo.svg", label: "Gangplank", pos: "b", w: 32, h: 32, constraint: "on" }
        traefik@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/traefik.png", label: "Traefik", pos: "b", w: 32, h: 32, constraint: "on" }
        pihole@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/pi-hole.png", label: "Pi-hole", pos: "b", w: 32, h: 32, constraint: "on" }
    end

    subgraph auth["Auth"]
        subgraph authrow[" "]
        direction LR
        tinyauth@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/tinyauth.png", label: "Tinyauth", pos: "b", w: 40, h: 40, constraint: "on" }
        pocketid@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/pocket-id.png", label: "Pocket ID", pos: "b", w: 40, h: 40, constraint: "on" }
        tinyauth <-->|"login"| pocketid
        end
    end

    subgraph ai["AI"]
        direction TB
        openwebui@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/open-webui.png", label: "Open WebUI", pos: "b", w: 40, h: 40, constraint: "on" }
        ollama@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/ollama.png", label: "Ollama", pos: "b", w: 40, h: 40, constraint: "on" }
        openwebui --> ollama
    end

    subgraph tools["Tools"]
        direction TB
        homepage@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/homepage.png", label: "Homepage", pos: "b", w: 40, h: 40, constraint: "on" }
        homarr@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/homarr.png", label: "Homarr", pos: "b", w: 40, h: 40, constraint: "on" }
        glances@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/glances.png", label: "Glances", pos: "b", w: 40, h: 40, constraint: "on" }
    end

    subgraph media["Media"]
        direction TB
        subgraph arr["Arr apps"]
            direction TB
            radarr@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/radarr.png", label: "Radarr", pos: "b", w: 40, h: 40, constraint: "on" }
            sonarr@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/sonarr.png", label: "Sonarr", pos: "b", w: 40, h: 40, constraint: "on" }
            prowlarr@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/prowlarr.png", label: "Prowlarr", pos: "b", w: 40, h: 40, constraint: "on" }
            bazarr@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/bazarr.png", label: "Bazarr", pos: "b", w: 40, h: 40, constraint: "on" }
            flaresolverr@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/flaresolverr.png", label: "FlareSolverr", pos: "b", w: 40, h: 40, constraint: "on" }
            configarr@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/configarr.png", label: "Configarr", pos: "b", w: 40, h: 40, constraint: "on" }
        end
        qbit@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/qbittorrent.png", label: "qBittorrent", pos: "b", w: 40, h: 40, constraint: "on" }
        subgraph servers["Media servers"]
            direction TB
            plex@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/plex.png", label: "Plex", pos: "b", w: 40, h: 40, constraint: "on" }
            jellyfin@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/jellyfin.png", label: "Jellyfin", pos: "b", w: 40, h: 40, constraint: "on" }
        end
        subgraph mtools["Media tools"]
            direction TB
            seerr@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/seerr.png", label: "Seerr", pos: "b", w: 40, h: 40, constraint: "on" }
            tracearr@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/tracearr.png", label: "Tracearr", pos: "b", w: 40, h: 40, constraint: "on" }
        end
    end

    subgraph auto["Automation"]
        direction TB
        homeassistant@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/home-assistant.png", label: "Home Assistant", pos: "b", w: 40, h: 40, constraint: "on" }
        homebridge@{ img: "https://raw.githubusercontent.com/selfhst/icons/main/png/homebridge.png", label: "Homebridge", pos: "b", w: 40, h: 40, constraint: "on" }
    end

    you -.->|"DNS lookup, LAN IP"| cloudflare
    you -->|"HTTPS at home"| traefik
    you -->|"away from home"| internet
    internet -->|"tailnet"| tailscale
    tailscale -->|"subnet route"| traefik
    internet -->|"public apps, :8443"| traefik
    internet ---|"VPN tunnel"| gluetun
    internet --- cloudflare
    cloudflare ---|"PUBLIC_DOMAIN, public IP"| ddns
    cloudflare ---|"ACME DNS challenge"| traefik
    internet ---|"port forwarding"| gangplank

    configarr -->|"configures"| radarr & sonarr & prowlarr & flaresolverr
    prowlarr -->|"Cloudflare challenges"| flaresolverr
    tracearr -->|"playback stats"| servers
    seerr -->|"requests"| arr

    traefik --> auth
    auth -->|"Tinyauth protects"| arr
    auth -->|"Pocket ID OIDC"| ai
    auth -->|"Pocket ID OIDC, Tinyauth"| tools

    arr -->|"sends downloads"| qbit
    gluetun -.-|"via VPN"| qbit

    traefik --> ai
    traefik --> tools
    traefik --> media
    traefik --> auto

    classDef group fill:none,stroke:#888,stroke-width:1.5px,stroke-dasharray:4 4
    classDef bare fill:none,stroke:none
    class authrow bare
    class net,auth,media,arr,servers,mtools,ai,auto,tools group
```

## Profiles

Set `COMPOSE_PROFILES` in `.env` to a comma-separated list of the
[Docker Compose profiles](https://docs.docker.com/compose/how-tos/profiles/) you want. A service
starts when any profile it belongs to is listed, so profiles add up: start from a group and add
single apps or categories on top.

There are three kinds of profile:

- **Groups** for a whole setup in one word: `basic`, `default` or `full`.
- **Categories** for related apps: `media`, `arrs`, `vpn`, `automation`, `tools`, `network`, `ai`
  and `auth`.
- **App profiles** for one app, named after its file in `apps/`: `sonarr`, `glances`, `pocket-id`
  and so on.

### Groups

| Group | Starts | Use it when |
| --- | --- | --- |
| `basic` | Media servers, the *arr apps, Seerr, Tracearr, FlareSolverr, qBittorrent behind the VPN, home automation, Homepage, Glances and DDNS Updater | You reach the apps by host port or over Tailscale, without Traefik |
| `default` | Everything in `basic`, plus Traefik | The usual setup, and the value `.env.example` ships with |
| `full` | Every long-running service in the repo, including AI, Pocket ID, Tinyauth, Homarr, Pi-hole, Tailscale and Gangplank | The host is dedicated to this stack and you want all of it |

The AI stack, Pocket ID, Tinyauth and Homarr are heavy or need extra setup. Pi-hole, Tailscale and
Gangplank change how the host or router behaves. So only `full` or their own profiles start them.
Configarr is in no group. It only runs when you call it, see Configarr under Media.

### Dependencies

Some profiles also start what the app needs to run:

- `qbittorrent` starts Gluetun, whose network it uses.
- `tinyauth` starts Pocket ID, its only login.
- `configarr` starts Sonarr, Radarr, Prowlarr and FlareSolverr, which it configures.
- `auth` starts Traefik, the only way to reach Pocket ID and Tinyauth.

Other links are optional. `sonarr` on its own starts only Sonarr.

### Examples

```dotenv
COMPOSE_PROFILES="default"                  # the usual stack behind Traefik
COMPOSE_PROFILES="default,auth,ai"          # plus Pocket ID and the AI stack
COMPOSE_PROFILES="default,homarr"           # plus one extra app
COMPOSE_PROFILES="plex,arrs,vpn,traefik"    # a media-only box
COMPOSE_PROFILES="full"                     # everything
```

To check what a value starts before launching it:

```bash
COMPOSE_PROFILES="default,auth" docker compose config --services
```

## Hardware

The stack runs on a UGREEN DXP2800 NAS:

- **CPU:** Intel N100 (4 cores, 4 threads). Its integrated graphics handle Plex hardware
  transcoding.
- **Memory:** 8 GB DDR5
- **Network:** 2.5 GbE

| Pool | Drives | Layout | Holds |
|---|---|---|---|
| Storage Pool 1 (Volume 1) | 2 × HDD | RAID 1 | Media, backups and other data (`MEDIA_DIR`, `BACKUP_DIR`) |
| Storage Pool 2 (Volume 2) | 1 × M.2 SSD | Basic | Docker images and volumes |
| SSD Cache 1 | 1 × M.2 SSD | Read cache | Speeds up reads from Storage Pool 1 |

## Setup

### Prerequisites

- A Linux host with Docker Engine and the Compose plugin (`docker compose version` works).
- A single media directory containing `Movies/`, `Shows/` and `Downloads/` subdirectories, for the
  `media`, `arrs` and `vpn` profiles.
- A domain on Cloudflare if you want Traefik and HTTPS. You will add `A` records pointing at the
  server's LAN IP, see [Networking](#networking).

### 1. Get the files and create the env files

```bash
git clone https://github.com/IonBazan/homelab.git
cd homelab
scripts/setup-env.sh
```

`scripts/setup-env.sh` does everything it can on its own:

- creates `.env` from `.env.example`;
- generates every random secret: the `*_API_KEY`s, the encryption keys, the Tracearr secrets and
  the qBittorrent, Pi-hole and Tracearr database passwords;
- detects `PHYSICAL_SERVER_IP`, `PHYSICAL_SERVER_NETWORK`, `TZ`, `PUID`, `PGID` and `RENDER_GID`, and
  `DOCKER_NETWORK_CIDR` once the `traefik` network exists;
- sets an empty `COMPOSE_PROFILES` to `default`, since an empty value starts nothing;
- with Pocket ID in the profiles, generates the Open WebUI and Homarr client secrets, and with
  Tinyauth, sets `TINYAUTH_ENABLED=true`;
- expands `~` in `MEDIA_DIR` and `BACKUP_DIR` and creates the folders under both;
- creates `.env.gluetun` from its template;
- checks the result with `docker compose config` and lists the tokens you still need to get.

It never overwrites a value you changed, and detected values only replace the example placeholders,
so you can run it again at any time.

To do it by hand instead:

```bash
cp .env.example .env
cp .env.gluetun.example .env.gluetun.nordvpn      # or .env.gluetun.wireguard
ln -sf .env.gluetun.nordvpn .env.gluetun          # pick the active VPN config
```

`.env`, `.env.gluetun` and every `.env.gluetun.*` file are gitignored because they hold your real
secrets. `.env.example` and `.env.gluetun.example` are the tracked templates.

### 2. Fill in `.env`

Work top to bottom. Anything left commented is optional and shown at its default. Rows that
`scripts/setup-env.sh` already filled are marked _(auto)_.

| Variable | Needed for | Where to get / how to set it |
|---|---|---|
| `DOMAIN_NAME` | Traefik, DNS | The domain you route services under, e.g. `homelab.example.com`. Every service is published at `<name>.${DOMAIN_NAME}`. |
| `TZ` | all | _(auto)_ IANA name, e.g. `Europe/Warsaw` ([list](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones)). |
| `PUID` / `PGID` | media apps | _(auto)_ `id -u` / `id -g` for the user that owns `MEDIA_DIR`. |
| `BACKUP_DIR` | app backups | **Required.** Absolute path that collects each app's scheduled backups in its own subdirectory, see [Backups](#7-backups). `scripts/setup-env.sh` creates the subdirectories. |
| `MEDIA_DIR` | media apps | Absolute path to the media root (holds `Movies/`, `Shows/`, `Downloads/`). `scripts/setup-env.sh` expands a leading `~` and creates the subdirectories. |
| `COMPOSE_PROFILES` | service selection | _(auto if blank)_ Comma-separated (see [Profiles](#profiles)). `default` is `basic` plus Traefik. Add single profiles to a group, e.g. `default,ai`. |
| `COMPOSE_FILE` | host ports | **Optional.** Set to `docker-compose.yaml:docker-compose.ports.yaml` to publish the web UIs on the host, see [Host ports](#host-ports). Unset means Traefik and Tailscale only. |
| `PHYSICAL_SERVER_IP` | Plex, Tailscale, DNS records | _(auto)_ Host LAN IP: `ip route get 1 \| awk '{print $7}'`. |
| `PHYSICAL_SERVER_NETWORK` | Tailscale subnet router | _(auto)_ Your LAN CIDR, e.g. `192.168.18.0/24`. |
| `PUBLIC_DOMAIN` | Plex remote access, public routers | A hostname in your Cloudflare zone, such as `public.example.tld`, that DDNS Updater keeps on your public IP, see [Public internet](#public-internet-optional). |
| `PLEX_CLAIM` | Plex first run | Fresh token from <https://www.plex.tv/claim> (valid about 4 minutes). Can be blanked after first start. |
| `TAILSCALE_TOKEN` | Tailscale | Tailscale admin → **Settings → Keys → Generate auth key**. Mark it *Reusable* and *Pre-approved* to skip manual route approval. |
| `CF_DNS_API_TOKEN` | Traefik HTTPS, DDNS Updater | Cloudflare → **My Profile → API Tokens → Create Token → "Edit zone DNS"**, scoped to your zone (`Zone:DNS:Edit` and `Zone:Zone:Read`). If `PUBLIC_DOMAIN` is in another zone, include both zones. |
| `CF_ZONE_ID` | DDNS Updater | Cloudflare → your domain → **Overview → Zone ID**, for the zone that holds `PUBLIC_DOMAIN`. It can differ from the `DOMAIN_NAME` zone. |
| `CF_API_EMAIL` | Traefik HTTPS | Your Cloudflare account email, used as the Let's Encrypt account email. |
| `TRAEFIK_DASHBOARD_AUTH` | Traefik dashboard | **Optional**, blank means no auth. `user:hash` from `htpasswd -nbB admin 'pass' \| sed -e 's/\$/\$\$/g'` (every `$` doubled for `.env`). |
| `HOMARR_SECRET_ENCRYPTION_KEY` | Homarr | _(auto)_ `openssl rand -hex 32` |
| `TRACEARR_JWT_SECRET` / `TRACEARR_COOKIE_SECRET` | Tracearr | _(auto)_ `openssl rand -hex 32` each |
| `SONARR_API_KEY` / `RADARR_API_KEY` / `PROWLARR_API_KEY` / `BAZARR_API_KEY` | Configarr | _(auto)_ `openssl rand -hex 16` each. Leave blank to let each app self-generate, in which case Configarr will not run. |
| `QBITTORRENT_PASSWORD` | qBittorrent WebUI | _(auto)_ Written to the WebUI login on every start and used by the Homepage widget, see qBittorrent below. Leave it blank to set the password in the UI. |
| `TINYAUTH_OIDC_CLIENT_SECRET` | Tinyauth | _(auto)_ Used only with the `auth` or `tinyauth` profile. `scripts/pocket-id-clients.sh` registers it in Pocket ID. `TINYAUTH_OIDC_CLIENT_ID` is optional and defaults to `tinyauth`. |
| `POCKET_ID_STATIC_API_KEY` | Pocket ID client setup | _(auto)_ Admin API key `scripts/pocket-id-clients.sh` uses to register clients. |
| `OPEN_WEBUI_OIDC_CLIENT_SECRET` / `HOMARR_OIDC_CLIENT_SECRET` | Pocket ID sign-in | _(auto)_ Generated only when Pocket ID is in the profiles, see Pocket ID below. |
| `DOCKER_NETWORK_CIDR` | Traefik API, qBittorrent | _(auto once the `traefik` network exists)_ Its subnet, trusted as a proxy. Defaults to `172.16.0.0/12`, which covers Docker's default address pools. |
| `PIHOLE_PASSWORD` | Pi-hole admin | _(auto)_ Used only with the `pihole` profile. |
| `RENDER_GID` | Plex HW transcode | _(auto)_ `getent group render \| cut -d: -f3` on the host. |
| `WEATHER_LATITUDE` / `WEATHER_LONGITUDE` | Homepage weather | **Optional.** Your location for the weather widget. |

### 3. Fill in `.env.gluetun` (only with the `vpn` profile)

`scripts/setup-env.sh` already created `.env.gluetun.nordvpn` and linked `.env.gluetun` to it. Edit
that file and uncomment **one** provider block. To use WireGuard instead, point the symlink at
`.env.gluetun.wireguard`.

- **NordVPN.** Dashboard → *NordVPN manual setup* → copy the **service credentials** into
  `OPENVPN_USER` and `OPENVPN_PASSWORD`.
- **Custom WireGuard.** Copy the values from your provider's `.conf` file
  (`WIREGUARD_PRIVATE_KEY`, `WIREGUARD_ADDRESSES`, peer `WIREGUARD_PUBLIC_KEY`, `VPN_ENDPOINT_IP`,
  `VPN_ENDPOINT_PORT`).

Gluetun gets its time zone and LAN subnet (`FIREWALL_OUTBOUND_SUBNETS`) from `TZ` and
`PHYSICAL_SERVER_NETWORK` in `.env`, so the qBittorrent WebUI stays reachable from the LAN while the
tunnel is up.

### 4. Create the folder layout

I keep everything in the home directory of the user that runs the stack:

```
~/
├── homelab/            this repository, run docker compose from here
├── Media/              MEDIA_DIR, mounted at /media in the media apps
│   ├── Movies/         Radarr root folder, Plex/Jellyfin movie library
│   ├── Shows/          Sonarr root folder, Plex/Jellyfin TV library
│   └── Downloads/      qBittorrent save path, hardlinked into Movies/Shows
└── Backups/            BACKUP_DIR, synced one way to the cloud
    ├── radarr/         one subfolder per app with built-in backups,
    ├── sonarr/         created by scripts/setup-env.sh (see Backups below)
    ├── prowlarr/
    ├── bazarr/
    ├── tracearr/
    └── homeassistant/
```

Any paths work. `scripts/setup-env.sh` creates this layout under `MEDIA_DIR` and `BACKUP_DIR`. Keep
`Downloads/` on the same filesystem as `Movies/` and `Shows/` so the *arr apps can hardlink instead
of copying.

### 5. Launch

```bash
docker compose up -d
```

With the `traefik` profile on, the first start issues one wildcard certificate over the Cloudflare
DNS-01 challenge. Follow it with `docker compose logs -f traefik`. Re-run the same command after any
`.env` change.

### 6. Configure the *arr apps

Once Sonarr, Radarr and Prowlarr have started once and created their databases, run Configarr. It
applies the TRaSH-Guides profiles, root folders, the qBittorrent download client, the Prowlarr app
links and the FlareSolverr proxy, then exits. `up -d` never runs it, so run it again after changing
[`config.yml`](apps/config/configarr/config.yml) or the qBittorrent password:

```bash
docker compose run --rm configarr
```

### 7. Backups

Apps that make their own scheduled backups write them to a subdirectory of `BACKUP_DIR`, mounted
over the app's default backup folder. Nothing in the stack uploads them. On my NAS, the OS syncs
`BACKUP_DIR` one way to a cloud provider. Any one-way sync tool (rclone, a NAS cloud sync task, a
Drive client) works too.

| Subdirectory | Mounted at | Schedule and retention set in |
|---|---|---|
| `radarr` | `/config/Backups` | Radarr > System > Backup (weekly by default) |
| `sonarr` | `/config/Backups` | Sonarr > System > Backup (weekly by default) |
| `prowlarr` | `/config/Backups` | Prowlarr > System > Backup (weekly by default) |
| `bazarr` | `/config/backup` | Bazarr > Settings > Backup (weekly by default) |
| `tracearr` | `/data/backup` | Tracearr's backup settings |
| `homeassistant` | `/config/backups` | Home Assistant > Settings > System > Backups |

The apps make these backups safely while running, so you can restore from them. Each app also
deletes its own old backups, so the sync tool should either mirror deletions or keep its own
history.

Each app must be able to write to its subdirectory. The linuxserver apps (Radarr, Sonarr, Prowlarr,
Bazarr) run as `PUID` and Home Assistant runs as root, so directories you own work for them.
Tracearr runs as uid 1001, so its directory must belong to that uid
([Tracearr docs](https://docs.tracearr.com/configuration/backup#permissions)):

```bash
sudo chown -R 1001 /path/to/backups/tracearr   # same path as BACKUP_DIR
```

`scripts/setup-env.sh` creates the subdirectories as your user and prints that command for Tracearr
(or runs it when started with `sudo`). If an app started before its directory existed, Docker
created the directory as `root:root` and the app fails with "Permission denied". Check with
`ls -ld` and give it back to your user, or to uid 1001 for Tracearr:

```bash
sudo chown -R "$(id -u):$(id -g)" /path/to/backups/radarr
```

## Networking

### DNS, one Cloudflare record for home and away

Create these records in Cloudflare with the server's **LAN IP**, set to **DNS only** (grey cloud).
Cloudflare's proxy cannot reach a private address, and the traffic should stay local anyway.

```
homelab.example.com     A   192.168.18.10
*.homelab.example.com   A   192.168.18.10
```

- **At home.** The name resolves to `192.168.18.10` and you connect directly over the LAN.
- **Away.** Connect to your tailnet. The Tailscale container advertises `PHYSICAL_SERVER_NETWORK` as
  a subnet route, so `192.168.18.10` is reachable through it.

The same public records work in both places, so you don't need split DNS or a local DNS server.

### TLS

Traefik (profile `traefik`) gets one wildcard certificate for `${DOMAIN_NAME}` and
`*.${DOMAIN_NAME}` through Cloudflare's **DNS-01** challenge. The challenge only needs the API token,
so the records can point at a LAN IP. Hostnames come from the container name: a service with
`traefik.enable: true` is live at `https://<container>.${DOMAIN_NAME}`. Open-WebUI (`ai.`),
Pocket ID (`id.`) and Homepage (`home.` and the bare domain) set their own hostnames.

The dashboard is at `https://${TRAEFIK_SUBDOMAIN:-traefik}.${DOMAIN_NAME}/dashboard/` (keep the
trailing slash). It has no login unless you set `TRAEFIK_DASHBOARD_AUTH` or `TINYAUTH_ENABLED`, see
Traefik below.

### Tailscale subnet router

The advertised route (`PHYSICAL_SERVER_NETWORK`) lets tailnet devices reach those LAN addresses from
anywhere. Approve the route and turn on IP forwarding on the host, see Tailscale below.

### Public internet (optional)

Use this only for services that need a real public address, such as Plex remote access. Set
`PUBLIC_DOMAIN` to a hostname in your Cloudflare zone, such as `public.example.tld`, and `CF_ZONE_ID`
to that zone's ID. DDNS Updater (profile `network`) then points `PUBLIC_DOMAIN` and
`*.PUBLIC_DOMAIN` at your public IP, using the same `CF_DNS_API_TOKEN` as Traefik. Its settings are
built from `.env` in the `CONFIG` variable of [`ddns-updater.yaml`](apps/network/ddns-updater.yaml),
so no credential ends up in a tracked file. For another DNS provider, change that JSON
([format](https://github.com/qdm12/ddns-updater#configuration)).

Forward the port on your router (Plex needs `32400/tcp`), or let Gangplank (profile `gangplank`) open
UPnP forwards for ports marked with a `gangplank.forward` label. Plex advertises both its LAN
address and `PUBLIC_DOMAIN` through `ADVERTISE_IP`.

A web app can also get a public hostname, `<app>.${PUBLIC_DOMAIN}`, served on Traefik's `public`
entrypoint. Forward WAN `443/tcp` to the host's `TRAEFIK_PUBLIC_PORT` (default `8443`). The wildcard
record makes every subdomain resolve. Only Tracearr does this today. To expose another app, add two
labels:

```yaml
traefik.http.routers.<app>.entrypoints: websecure,public
homelab.public: true
```

`homelab.public` makes Traefik's default rule also match `<app>.${PUBLIC_DOMAIN}`, and the
entrypoints label adds the router to the `public` entrypoint. Apps without these labels stay
LAN-only. Only expose apps that have their own login.

Public hostnames use a separate wildcard certificate for `${PUBLIC_DOMAIN}` and `*.${PUBLIC_DOMAIN}`,
from the same DNS challenge. A small `public-cert` router on the Traefik container requests it, so a
failed public renewal cannot affect the main certificate. That router answers the bare
`${PUBLIC_DOMAIN}` with `418`. Public subdomains with no app behind them return `404`.

Everything else stays private to the LAN and the tailnet.

### Pi-hole (optional)

Pi-hole is a network-wide ad blocker (profile `pihole`, or `full`). Routing does not need it. If
your devices use it for DNS, it answers `*.${DOMAIN_NAME}` with `PHYSICAL_SERVER_IP` locally, in
place of the Cloudflare records.

It binds port 53 on the host. On Ubuntu and other distributions where `systemd-resolved` already
listens there, turn off its stub listener first:

```bash
sudo sed -i 's/^#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo systemctl restart systemd-resolved
```

## Application list

### AI

#### [Ollama](https://ollama.com) ([definition](apps/ai/ollama.yaml))
Runs LLMs locally and exposes an API for managing models on your own hardware.
- **Ports:** 11434:11434/tcp (OLLAMA_PORT), overlay only, see [Host ports](#host-ports)
- **Profiles:** `ollama`, `ai`, `full`
- Proxied by Traefik at `https://ollama.${DOMAIN_NAME}`.

#### [Open-WebUI](https://openwebui.com) ([definition](apps/ai/open-webui.yaml))
Web interface for local LLMs, built to work with Ollama and similar backends.
- **Ports:** 3000:8080/tcp (OPEN_WEBUI_PORT), overlay only, see [Host ports](#host-ports)
- **Profiles:** `open-webui`, `ai`, `full`
- Proxied by Traefik at `https://ai.${DOMAIN_NAME}`.

It does not connect to Ollama on its own. Add `http://ollama:11434` under *Admin Panel > Settings >
Connections*, or the Ollama URL of another machine.

### Auth

#### [Pocket ID](https://pocket-id.org) ([definition](apps/auth/pocket-id.yaml))
OpenID Connect provider that signs users in with passkeys, for apps that support OIDC login.
- **Ports:** 1411:1411/tcp (POCKET_ID_PORT), overlay only, see [Host ports](#host-ports)
- **Profiles:** `pocket-id`, `tinyauth`, `auth`, `full` (`auth` starts Traefik, `pocket-id` alone needs `traefik`)
- Proxied by Traefik at `https://id.${DOMAIN_NAME}`.

`APP_URL` is set to the Traefik hostname. Passkeys only work over HTTPS on the domain they were
created for, so use the host port only for troubleshooting. Create the first admin account at
`https://id.${DOMAIN_NAME}/setup`.

Single sign-on is optional for each app. It turns on when the app's client secret is set in `.env`.
`scripts/setup-env.sh` generates the secrets when `COMPOSE_PROFILES` includes `auth`, `pocket-id`,
`tinyauth` or `full`, and `scripts/pocket-id-clients.sh` registers the clients in Pocket ID. Each
app keeps its own login next to the Pocket ID button, so you can still sign in when Pocket ID is
down.

| App | `.env` variables | Client ID (default) | Callback URL |
| --- | --- | --- | --- |
| Open-WebUI | `OPEN_WEBUI_OIDC_CLIENT_SECRET`, optional `_ID` | `open-webui` | `https://ai.${DOMAIN_NAME}/oauth/oidc/callback` |
| Homarr | `HOMARR_OIDC_CLIENT_SECRET`, optional `_ID` | `homarr` | `https://homarr.${DOMAIN_NAME}/api/auth/callback/oidc` |

Open-WebUI links a Pocket ID login to an existing account with the same email. Homarr creates a
separate user for it.

Tinyauth is different. Pocket ID is its only login, see Tinyauth below.

[`scripts/pocket-id-clients.sh`](scripts/pocket-id-clients.sh) runs on the server and needs only
`curl`. It reads `.env` and uses `POCKET_ID_STATIC_API_KEY` to create each client at
`https://id.${DOMAIN_NAME}` with the ID and secret from `.env`. Running it again leaves existing
clients alone and only adds a missing secret, so changes you make in the Pocket ID UI stay. To add a
client, add a `register` line to the script. The static key has full admin access to Pocket ID, so
keep it as safe as `POCKET_ID_ENCRYPTION_KEY`.

#### [Tinyauth](https://tinyauth.app) ([definition](apps/auth/tinyauth.yaml))
Forward-auth login page that Traefik puts in front of Sonarr, Radarr, Prowlarr, Bazarr, Homepage,
Glances, DDNS Updater and the Traefik dashboard.
- **Ports:** none, reachable only through Traefik
- **Profiles:** `tinyauth`, `auth`, `full` (starts Pocket ID; `auth` starts Traefik, `tinyauth` alone needs `traefik`)
- Proxied by Traefik at `https://tinyauth.${DOMAIN_NAME}`.

Pocket ID is the only way to sign in. Tinyauth has no local users and sends browsers straight to
Pocket ID, so while Pocket ID is down, nobody can open the protected apps through Traefik.

To set it up:

1. Add `auth` to `COMPOSE_PROFILES`, or use `full`. Both start Traefik, Pocket ID and Tinyauth. If
   you add only `tinyauth`, Traefik has to come from another profile such as `default`.
2. Run `scripts/setup-env.sh`, or set `POCKET_ID_STATIC_API_KEY` and `TINYAUTH_OIDC_CLIENT_SECRET` in
   `.env` yourself (`openssl rand -hex 32` each).
3. Run `docker compose up -d`, then `scripts/pocket-id-clients.sh` once Pocket ID answers at
   `https://id.${DOMAIN_NAME}`. It registers the `tinyauth` client with the callback
   `https://tinyauth.${DOMAIN_NAME}/api/oauth/callback/pocketid`.
4. Create the first admin account at `https://id.${DOMAIN_NAME}/setup`, if you have not already.
   To let only some users in, open the Tinyauth client under **OIDC Clients** and pick a group
   under **Allowed User Groups**. Otherwise every Pocket ID user can sign in.
5. Open `https://sonarr.${DOMAIN_NAME}`. You should land on Pocket ID, and after signing in you
   are sent back to Sonarr.

Browsers must sign in before they see an app's UI. API paths skip Tinyauth, so mobile apps, the
other *arrs, Prowlarr sync and calendar feeds keep working. The app still checks its API key there:

| App | Paths that skip Tinyauth |
| --- | --- |
| Sonarr, Radarr | `^/(api\|feed\|ping)` |
| Prowlarr | `^/(api\|ping\|\d+/(api\|download))` |
| Bazarr | `^/api` |

The rules are `tinyauth.apps.*` labels on each app.

> [!CAUTION]
> `TINYAUTH_ENABLED` turns off the built-in login of Sonarr, Radarr and Prowlarr. They switch to the
> `External` method and trust Tinyauth to check who you are. Set it only together with a profile
> that runs Tinyauth (`auth`, `tinyauth` or `full`), and remove both together. Anything that reaches
> these apps without going through Tinyauth gets in with no login, including host ports from the
> ports overlay. Clearing the flag does not bring the old login back, so set each app's login method
> back by hand.

`TINYAUTH_ENABLED=true` in `.env` turns it on. `scripts/setup-env.sh` sets it when
`COMPOSE_PROFILES` includes `auth`, `tinyauth` or `full`. The Traefik routers of Sonarr, Radarr,
Prowlarr, Bazarr, Homepage, Glances, DDNS Updater and the Traefik dashboard then use the `tinyauth`
middleware. Sonarr, Radarr and Prowlarr switch to the `External` login method, so you only sign in
once. Bazarr has no such method and keeps its own login. qBittorrent is not behind Tinyauth.

Keep in mind:

- If Tinyauth is not running while the flag is set, those apps return 404 instead of opening
  without a login.
- Host ports from the ports overlay skip Traefik, so they have no Tinyauth login.
- To turn it off, clear the flag and set the login method back in each *arr app
  (**Settings → General → Authentication**). The flag only sets `External`. It does not restore the
  old method.

To check that the API bypass works, call an API path without a key. The app itself should answer
`401`, with no redirect to Pocket ID, and the same request with the key should return `200`:

```bash
curl -s -o /dev/null -w "%{http_code}\n" https://sonarr.${DOMAIN_NAME}/api/v3/system/status
curl -s -o /dev/null -w "%{http_code}\n" -H "X-Api-Key: $SONARR_API_KEY" https://sonarr.${DOMAIN_NAME}/api/v3/system/status
```

### Automation

#### [Home Assistant](https://www.home-assistant.io) ([definition](apps/automation/homeassistant.yaml))
Home automation platform that runs locally and works with most smart home devices.
- **Ports:** host (8123 by default)
- **Profiles:** `homeassistant`, `automation`, `basic`, `default`, `full`
- Proxied by Traefik at `https://homeassistant.${DOMAIN_NAME}`.

Home Assistant rejects requests through Traefik until it trusts it as a proxy. Finish the first-run
setup at `http://<server ip>:8123`, then add `DOCKER_NETWORK_CIDR` from `.env` under
**Settings > System > Network > Trusted proxies**, or as `http.trusted_proxies` in
`configuration.yaml`.

#### [Homebridge](https://homebridge.io) ([definition](apps/automation/homebridge.yaml))
Adds devices that don't support HomeKit to Apple Home.
- **Ports:** host (8581 by default)
- **Profiles:** `homebridge`, `automation`, `basic`, `default`, `full`
- Proxied by Traefik at `https://homebridge.${DOMAIN_NAME}`.

### Media

#### [Jellyfin](https://jellyfin.org) ([definition](apps/media/jellyfin.yaml))
Free media server for your own library.
- **Ports:** 8096:8096/tcp, 8920:8920/tcp (JELLYFIN_PORT, JELLYFIN_HTTPS_PORT), overlay only, see [Host ports](#host-ports)
- **Profiles:** `jellyfin`, `media`, `basic`, `default`, `full`

#### [Plex](https://www.plex.tv) ([definition](apps/media/plex.yaml))
Media server that streams your library to almost any device.
- **Ports:** 32400:32400/tcp (configurable via PLEX_PORT), 8324:8324/tcp, 32469:32469/tcp, 1900:1900/udp, 32410:32410/udp, 32412:32412/udp, 32413:32413/udp, 32414:32414/udp. Always published, because Plex clients connect directly.
- **Profiles:** `plex`, `media`, `basic`, `default`, `full`

It gets the host's `/dev/dri` for Intel Quick Sync and VAAPI hardware transcoding. `RENDER_GID` in
`.env` must be the host's `render` group id (`scripts/setup-env.sh` detects it). Then turn on
*Settings > Transcoder > Use hardware acceleration when available* in Plex, which needs Plex Pass.
Transcodes go to `/transcode` (`PLEX_TRANSCODE_DIR`, default `/tmp`) instead of the config volume.

#### [Prowlarr](https://prowlarr.com) ([definition](apps/media/prowlarr.yaml))
Manages Usenet and torrent indexers for the *arr apps.
- **Ports:** 9696:9696/tcp (PROWLARR_PORT), overlay only, see [Host ports](#host-ports)
- **Profiles:** `prowlarr`, `configarr`, `arrs`, `media`, `basic`, `default`, `full`

#### [FlareSolverr](https://github.com/FlareSolverr/FlareSolverr) ([definition](apps/media/flaresolverr.yaml))
Solves Cloudflare challenges for Prowlarr indexers that use them.
- **Ports:** none, reached by Prowlarr over the `traefik` network
- **Profiles:** `flaresolverr`, `configarr`, `arrs`, `media`, `basic`, `default`, `full`

Configarr adds it to Prowlarr as an indexer proxy with the `flaresolverr` tag. Prowlarr only uses it
for indexers with the same tag, so add `flaresolverr` to each indexer behind a Cloudflare challenge.

#### [qBittorrent](https://www.qbittorrent.org) ([definition](apps/media/qbittorrent.yaml))
BitTorrent client with a web UI. Its traffic goes through the VPN.
- **Ports:** published on the `gluetun` container. `${QBITTORRENT_PORT:-8081}:8081/tcp` for the WebUI ([overlay only](#host-ports)), `${TORRENT_PORT:-6881}/tcp+udp` for torrents (always published).
- **Profiles:** `qbittorrent`, `vpn`, `basic`, `default`, `full`
- **Traefik:** its router is defined on the `gluetun` service, because qBittorrent shares gluetun's network namespace.

The seed config [`qBittorrent.conf`](apps/config/qbittorrent/qBittorrent.conf) is mounted over the
image's default, and the image copies it into the `qbittorrent_data` volume **only on the first
start**. It accepts the legal notice, saves downloads to `/media/Downloads` and prepares the WebUI
for a reverse proxy.

On every start, [`webui-login.sh`](apps/config/qbittorrent/webui-login.sh) runs before qBittorrent
launches. It sets `WebUI\TrustedReverseProxiesList` to `DOCKER_NETWORK_CIDR`, so qBittorrent sees the
real client addresses behind Traefik. If `QBITTORRENT_PASSWORD` is set, it also writes the WebUI
username and password hash in qBittorrent's own format. It only touches the file when a value
changes, so the login survives restarts and recreates. The Homepage widget uses the same username
and password.

With `QBITTORRENT_PASSWORD` set, change the password **in `.env`, not in the UI**, because the next
start reverts changes made in the UI. Configarr then also adds qBittorrent to Sonarr and Radarr for
you. With it blank, qBittorrent owns the login. It logs a temporary password on first start
(`docker compose logs qbittorrent | grep -i password`) and keeps whatever you set under
*Options > Web UI*, and you add it to each *arr by hand.

To apply the full seed again, delete the `qbittorrent_data` volume. The torrent listen port is not
set, so qBittorrent picks one on first run. Set it in the UI to match `TORRENT_PORT` for inbound
connections through the VPN. The WebUI **asks for a login on every path**, because the subnet
whitelist is off.

#### [Radarr](https://radarr.video) ([definition](apps/media/radarr.yaml))
Finds, downloads and organizes movies from Usenet and torrents.
- **Ports:** 7878:7878/tcp (RADARR_PORT), overlay only, see [Host ports](#host-ports)
- **Profiles:** `radarr`, `configarr`, `arrs`, `media`, `basic`, `default`, `full`

#### [Bazarr](https://www.bazarr.media) ([definition](apps/media/bazarr.yaml))
Downloads and manages subtitles for Radarr and Sonarr.
- **Ports:** 6767:6767/tcp (BAZARR_PORT), overlay only, see [Host ports](#host-ports)
- **Profiles:** `bazarr`, `arrs`, `media`, `basic`, `default`, `full`

Its API key comes from `BAZARR_API_KEY` in `.env` (through `BAZARR__AUTH__APIKEY`), so it stays the
same after a config reset. `scripts/setup-env.sh` generates it.

#### [Tracearr](https://tracearr.com) ([definition](apps/media/tracearr.yaml))
Tracks playback and shows statistics for Plex, Jellyfin and Emby. Comes with its own TimescaleDB and
Redis containers on a private `tracearr` network.
- **Ports:** 3001:3000/tcp (TRACEARR_PORT), overlay only, see [Host ports](#host-ports)
- **Profiles:** `tracearr`, `media`, `basic`, `default`, `full`

Needs `TRACEARR_JWT_SECRET` and `TRACEARR_COOKIE_SECRET` in `.env`, which `scripts/setup-env.sh`
generates. It is also public at `tracearr.${PUBLIC_DOMAIN}`, see
[Public internet](#public-internet-optional).

#### [Seerr](https://github.com/seerr-team/seerr) ([definition](apps/media/seerr.yaml))
Request manager for Plex and Jellyfin. Users ask for a film or show, and approved requests go to
Radarr and Sonarr. It replaces Overseerr and Jellyseerr.
- **Ports:** 5055:5055/tcp (SEERR_PORT), overlay only, see [Host ports](#host-ports)
- **Profiles:** `seerr`, `arrs`, `media`, `basic`, `default`, `full`

Set it up in its wizard on first visit. Pick Plex or Jellyfin, sign in, then add Radarr and Sonarr
under *Settings > Services* at `http://radarr:7878` and `http://sonarr:8989`, with the API keys from
`.env`. For the Homepage widget, copy *Settings > General > API Key* into `SEERR_API_KEY`.

#### [Sonarr](https://sonarr.tv) ([definition](apps/media/sonarr.yaml))
Finds, downloads and organizes TV shows from Usenet and torrents.
- **Ports:** 8989:8989/tcp (SONARR_PORT), overlay only, see [Host ports](#host-ports)
- **Profiles:** `sonarr`, `configarr`, `arrs`, `media`, `basic`, `default`, `full`

Its API key comes from `SONARR_API_KEY` in `.env` (through `SONARR__AUTH__APIKEY`), so it stays the
same after a config reset. Radarr works the same way with `RADARR_API_KEY`. `scripts/setup-env.sh`
generates both.

#### [Configarr](https://configarr.de) ([definition](apps/media/configarr.yaml))
Syncs [TRaSH-Guides](https://trash-guides.info/) custom formats, quality definitions and quality
profiles into Sonarr and Radarr, driven by [`apps/config/configarr/config.yml`](apps/config/configarr/config.yml).
- **Ports:** none (run-once container)
- **Profiles:** `configarr` only, so `docker compose up -d` never starts it

It needs `SONARR_API_KEY`, `RADARR_API_KEY` and `PROWLARR_API_KEY` in `.env`, reads them with
`!env`, and reaches each app over the `traefik` network. It sets Sonarr's root folder to
`/media/Shows` and Radarr's to `/media/Movies`.

It also adds the **qBittorrent download client** to both apps. The client is defined once in
`config.yml` and shared with a YAML anchor, which needs `CONFIGARR_ENABLE_MERGE=true` on the
container. It points at `gluetun:8081`, because qBittorrent uses gluetun's network, and uses the
categories `tv-sonarr` and `radarr`. It signs in with `QBITTORRENT_USERNAME` and
`QBITTORRENT_PASSWORD`, and `update_password: true` sends the password on every run so it stays in
sync with `.env`. Without `QBITTORRENT_PASSWORD` the client has no password and cannot connect.

In **Prowlarr** it adds Sonarr and Radarr as applications with `fullSync`, the same qBittorrent
client, and the FlareSolverr proxy tagged `flaresolverr`. Then it runs *Sync App Indexers* to push
every Prowlarr indexer into both apps. It does not manage indexers. Add them in the Prowlarr UI and
run Configarr again, or let Prowlarr's own sync handle them. The applications have no tags on
purpose, because a tagged application only gets indexers with the same tag. Configarr deletes
nothing, so anything you added by hand stays.

It only runs when you call it. Naming a service on the command line turns on its profile, whatever
`COMPOSE_PROFILES` says. It starts Sonarr, Radarr, Prowlarr and FlareSolverr if needed, applies the
config and exits:

```bash
docker compose run --rm configarr
```

### Network

#### [DDNS Updater](https://github.com/qdm12/ddns-updater) ([definition](apps/network/ddns-updater.yaml))
Keeps your DNS records pointed at your current public IP.
- **Ports:** 8001:8000/tcp (DDNS_UPDATER_PORT), overlay only, see [Host ports](#host-ports)
- **Profiles:** `ddns-updater`, `network`, `basic`, `default`, `full`

Updates `PUBLIC_DOMAIN` and `*.PUBLIC_DOMAIN` on Cloudflare. Needs `CF_DNS_API_TOKEN`, `CF_ZONE_ID`
and `PUBLIC_DOMAIN` in `.env`, see [Public internet](#public-internet-optional).

#### [Gangplank](https://github.com/IonBazan/gangplank) ([definition](apps/network/gangplank.yaml))
Opens UPnP port forwards on your router for the container ports you label.
- **Ports:** host
- **Profiles:** `gangplank`, `full`

#### [Gluetun](https://github.com/qdm12/gluetun) ([definition](apps/network/gluetun.yaml))
VPN client that other containers (here, qBittorrent) send their traffic through.
- **Ports:** 8081/tcp for the qBittorrent WebUI (`QBITTORRENT_PORT`, [overlay only](#host-ports)), 6881/tcp+udp for torrents (`TORRENT_PORT`, always published)
- **Profiles:** `gluetun`, `qbittorrent`, `vpn`, `basic`, `default`, `full`

The VPN provider settings live in their own file instead of `.env`. Copy `.env.gluetun.example` to a
file for your provider, fill in the credentials, then link it as the active config:

```bash
cp .env.gluetun.example .env.gluetun.nordvpn    # or .env.gluetun.wireguard
# edit the file and fill in credentials
ln -sf .env.gluetun.nordvpn .env.gluetun         # make it active
docker compose up -d --force-recreate gluetun qbittorrent
```

To switch providers, point the link at another file and recreate the containers:

```bash
ln -sf .env.gluetun.wireguard .env.gluetun
docker compose up -d --force-recreate gluetun qbittorrent
```

#### [Pi-hole](https://pi-hole.net) ([definition](apps/network/pihole.yaml))
Network-wide ad blocker. Routing does not need it (see [Networking](#networking)). It also answers
`*.${DOMAIN_NAME}` with `PHYSICAL_SERVER_IP`, a local alternative to the Cloudflare records.
- **Ports:** 53:53/tcp and 53:53/udp (always published), 81:80/tcp for the admin UI (PIHOLE_WEB_PORT, [overlay only](#host-ports))
- **Profiles:** `pihole`, `full`

#### [Tailscale](https://tailscale.com) ([definition](apps/network/tailscale.yaml))
VPN built on WireGuard that connects your devices. Here it gives you access to the LAN from anywhere.
- **Ports:** host
- **Profiles:** `tailscale`, `full`

It runs as a subnet router. `TS_ROUTES` advertises `PHYSICAL_SERVER_NETWORK`, so devices on your
tailnet can reach LAN addresses, including `PHYSICAL_SERVER_IP`, through this node. After the first
start, approve the route under *Machines > this host > Route settings* in the
[Tailscale admin console](https://login.tailscale.com/admin/machines), or pre-approve it with an
`autoApprovers` ACL. The host also needs IP forwarding enabled:

```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
```

#### [Traefik](https://traefik.io/traefik/) ([definition](apps/network/traefik.yaml))
Reverse proxy in front of every web UI in the stack.
- **Ports:** 80:80/tcp, 443:443/tcp, 8443:8443/tcp (TRAEFIK_PUBLIC_PORT)
- **Profiles:** `traefik`, `auth`, `default`, `full`

It routes every container with `traefik.enable: true` at `<container>.${DOMAIN_NAME}` (see
[Networking](#networking)). TLS uses one wildcard certificate for `${DOMAIN_NAME}` and
`*.${DOMAIN_NAME}` from the Cloudflare DNS-01 challenge. It is set as the default certificate in the
Traefik container's labels (`tls.stores.default.defaultgeneratedcert`), so no app requests its own.
Certificates are stored in the `traefik_certs` volume. Delete `acme.json` there to get a new one.
Needs `CF_DNS_API_TOKEN` and `CF_API_EMAIL` in `.env`.

The dashboard is at `https://${TRAEFIK_SUBDOMAIN:-traefik}.${DOMAIN_NAME}/dashboard/` (keep the
trailing slash). It has **no login by default**. Set `TRAEFIK_DASHBOARD_AUTH` in `.env` for HTTP basic
auth, or `TINYAUTH_ENABLED` for the Tinyauth login:

```bash
htpasswd -nbB admin 'yourpassword' | sed -e 's/\$/\$\$/g'   # paste result as TRAEFIK_DASHBOARD_AUTH
```

Homepage answers both `${DOMAIN_NAME}` and `home.${DOMAIN_NAME}`. A request for any other host, such
as another domain, a `*.local` name, the bare LAN IP or an old bookmark, gets a 302 to
`TRAEFIK_CATCHALL_URL`. Set it in `.env`, for example `http://naslab.local:9999`, or leave it blank
to turn the redirect off. The HTTP to HTTPS redirect only applies to `${DOMAIN_NAME}`, so those other
hosts reach the redirect over plain HTTP without a certificate warning. Unknown subdomains of
`${DOMAIN_NAME}` return 404 instead of redirecting.

The bare host `traefik` skips the catch-all. A router on the `web` entrypoint sends it to the Traefik
API, so the Homepage widget can read `http://traefik` over the Docker network. An IP allowlist
(`127.0.0.1/32` and `DOCKER_NETWORK_CIDR`) blocks LAN clients that fake the `Host` header, so the API
needs no login and stays private.

The third entrypoint, `public` on port 8443, takes traffic from the internet. Only routers that list
`public` in their entrypoints listen on it, so a WAN forward to it cannot reach a LAN-only app, even
with a fake `Host` header. It serves a separate wildcard certificate for `${PUBLIC_DOMAIN}`, see
[Public internet](#public-internet-optional).

The `middlewares-secure-headers` middleware (nosniff, frame options, referrer and permissions policy)
applies to every route on the `websecure` and `public` entrypoints. Change it in
[`middlewares.yml`](apps/config/traefik/rules/middlewares.yml).

### Tools

#### [Homepage](https://gethomepage.dev) ([definition](apps/tools/homepage.yaml))
Start page that lists every service, with live stats and info widgets at the top (system resources,
weather, clock, web search).
- **Ports:** 3002:3000/tcp (HOMEPAGE_PORT), overlay only, see [Host ports](#host-ports)
- **Profiles:** `homepage`, `tools`, `basic`, `default`, `full`
- Reachable at `https://home.${DOMAIN_NAME}` and at the bare apex `https://${DOMAIN_NAME}`.

The page builds itself from the `homepage.*` labels on each container, so a new service shows up on
its own. Info widgets and layout are in [`apps/config/homepage/`](apps/config/homepage/). Set
`WEATHER_LATITUDE` and `WEATHER_LONGITUDE` in `.env` for the weather widget. Icons come from
[selfh.st](https://selfh.st/icons/) (`sh-<name>.webp`), with `mdi-…` icons for the few missing there.

A service tile shows live stats when its credential is set in `.env`. Otherwise it is just a link.
The credentials are Sonarr, Radarr and Prowlarr (`*_API_KEY`), Pi-hole (`PIHOLE_PASSWORD`), Plex
(`PLEX_TOKEN`), Jellyfin (`JELLYFIN_API_KEY`), Bazarr (`BAZARR_API_KEY`), Seerr (`SEERR_API_KEY`),
Tracearr (`TRACEARR_API_KEY`), Home Assistant (`HOMEASSISTANT_TOKEN`) and qBittorrent
(`QBITTORRENT_USERNAME`, `QBITTORRENT_PASSWORD`).

#### [Homarr](https://homarr.dev) ([definition](apps/tools/homarr.yaml))
Another dashboard, set up through its own UI.
- **Ports:** 7575:7575/tcp (HOMARR_PORT), overlay only, see [Host ports](#host-ports)
- **Profiles:** `homarr`, `full`
- Proxied by Traefik at `https://homarr.${DOMAIN_NAME}`.

It does the same job as Homepage, so you only need one. It uses much more RAM than the other tools,
so it has its own profile instead of being in `tools`, and only `full` starts it. To add it to the
default set:

```dotenv
COMPOSE_PROFILES="default,homarr"
```

#### [Glances](https://nicolargo.github.io/glances/) ([definition](apps/tools/glances.yaml))
Shows the host's CPU, memory, disks, processes and containers. Homepage shows a summary.
- **Ports:** 61208:61208/tcp (GLANCES_PORT), overlay only, see [Host ports](#host-ports)
- **Profiles:** `glances`, `tools`, `basic`, `default`, `full`
- Proxied by Traefik at `https://glances.${DOMAIN_NAME}`.

It uses the host's process namespace and the Docker socket, so CPU, memory, disk and process numbers
are the host's. Network numbers are the container's own, because it stays on the `traefik` network.
The web UI has no login of its own (only Tinyauth's, when `TINYAUTH_ENABLED` is set), so keep it off
the public internet.

## Testing

`tests/validate-compose.sh` renders the whole stack with placeholder values instead of your `.env`,
with and without the ports overlay. It then checks which services each profile starts, including
that each app's own profile starts that app. Run it after changing any compose file:

```bash
tests/validate-compose.sh
```

It needs only Docker Compose and starts no containers.

## Contributing

This is my personal homelab setup, so I may not accept contributions. Feel free to fork this
repository and use it for your own homelab.
