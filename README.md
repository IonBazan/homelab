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
- `tools` - additional tools like Portainer
- `all` - All above

Additionally, following are not included in `all` as they are quite optional:
- `traefik` - Traefik
- `ai` - AI tools like Ollama and Open-WebUI

#### Environment variables

Most ports are configurable via _optional_ environment variables. Check out individual services config to learn more.
Tokens, subdomains and other configuration can be found in `.env.example`.

You can also customize default restart policy using `UNIVERSAL_RESTART_POLICY` variable (defaults to `unless-stopped`).

### Portability

Easy to set up - simply copy the files to any machine, change `.env` parameters and run `docker-compose up -d`. No complex makefiles, Ansible or bash scripts. Works on most platforms and architectures out of the box.

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
- **Ports:** 32400:32400/tcp, 8324:8324/tcp, 32469:32469/tcp, 1900:1900/udp, 32410:32410/udp, 32412:32412/udp, 32413:32413/udp, 32414:32414/udp
- **Profiles:** `media`, `all`

#### [Prowlarr](apps/media/prowlarr.yaml)
An indexer manager/proxy for *arr applications, supporting Usenet and BitTorrent indexers.
- **Ports:** 9696:9696/tcp (configurable via PROWLARR_PORT)
- **Profiles:** `media`, `arrs`, `all`

#### [qBittorrent](apps/media/qbittorrent.yaml)
A feature-rich and open-source BitTorrent client with a web UI, running behind a VPN for privacy.
- **Ports:** 8081:8080/tcp (configurable via QBITTORRENT_PORT)
- **Profiles:** `vpn`, `all`

#### [Radarr](apps/media/radarr.yaml)
A movie collection manager for Usenet and BitTorrent users, automating downloads and organization.
- **Ports:** 7878:7878/tcp (configurable via RADARR_PORT)
- **Profiles:** `media`, `arrs`, `all`

#### [Bazarr](apps/media/bazarr.yaml)
A companion app for Radarr and Sonarr that manages and downloads subtitles for movies and TV series.
- **Ports:** 6767:6767/tcp (configurable via BAZARR_PORT)
- **Profiles:** `media`, `arrs`, `all`

#### [Sonarr](apps/media/sonarr.yaml)
A TV series collection manager for Usenet and BitTorrent users, automating downloads and organization.
- **Ports:** 8989:8989/tcp (configurable via SONARR_PORT)
- **Profiles:** `media`, `arrs`, `all`

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
VPN client container to route traffic of other containers through a secure VPN tunnel.
- **Ports:** (none by default)
- **Profiles:** `vpn`, `all`

#### [NetAlertX](apps/network/netalertx.yaml)
Network device monitoring and alerting tool for your home network.
- **Ports:** host
- **Profiles:** (not specified)

#### [Pi-hole](apps/network/pihole.yaml)
Network-wide ad blocker and DNS sinkhole for privacy and security.
- **Ports:** 53:53/tcp, 53:53/udp, 81:80/tcp
- **Profiles:** (not specified)

#### [Tailscale](apps/network/tailscale.yaml)
Zero-config VPN to connect your devices and networks securely using WireGuard.
- **Ports:** host
- **Profiles:** (not specified)

#### [Traefik](apps/network/traefik.yaml)
Modern reverse proxy and load balancer for microservices and web applications.
- **Ports:** 80:80/tcp, 443:443/tcp, 8080:8080/tcp
- **Profiles:** `traefik`

#### [Whoami](apps/network/whoami.yaml)
A tiny Go webserver that prints OS and request information, useful for testing and debugging.
- **Ports:** (not specified)
- **Profiles:** (not specified)

### Tools

#### [Dockpeek](apps/tools/dockpeek.yaml)
A web UI for monitoring and managing Docker containers.
- **Ports:** 8000:8000/tcp (configurable via DOCKPEEK_PORT)
- **Profiles:** (not specified)

#### [Portainer](apps/tools/portainer.yaml)
A lightweight management UI for Docker, Docker Swarm, and Kubernetes.
- **Ports:** 8000:8000/tcp, 9000:9000/tcp, 9443:9443/tcp
- **Profiles:** `tools`, `all`

#### [Homepage](apps/tools/homepage.yaml)
A modern, customizable dashboard for your self-hosted services.
- **Ports:** 3000:3000/tcp (configurable via HOMEPAGE_PORT)
- **Profiles:** (not specified)

#### [OpenList](apps/tools/openlist.yaml)
A file listing and sharing service for local and remote storage providers, with the shared media volume mounted at `/media`.
- **Ports:** 5244:5244/tcp (configurable via OPENLIST_PORT), 5245:5245/tcp (configurable via OPENLIST_S3_PORT)
- **Profiles:** `tools`, `all`

## Contributing

As this is my personal homelab setup, I may not accept any contributions but feel free to fork this repository and use it for your own homelab.
