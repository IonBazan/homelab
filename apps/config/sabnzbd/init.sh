#!/usr/bin/with-contenv bash
# Runs as root from /custom-cont-init.d on every start, before SABnzbd launches.
# SABnzbd rejects hostnames missing from host_whitelist unless a login is set, which
# would block Traefik and the other containers. On the first start it also seeds the
# download folders under /media/Downloads.
INI=/config/sabnzbd.ini

if [ ! -f "$INI" ]; then
  printf '[misc]\ndownload_dir = /media/Downloads/usenet/incomplete\ncomplete_dir = /media/Downloads/usenet\n' > "$INI"
  chown abc:abc "$INI"
fi

set_misc() {
  if grep -q "^$1 = " "$INI"; then
    sed -i "s|^$1 = .*|$1 = $2|" "$INI"
  else
    sed -i "/^\[misc\]/a $1 = $2" "$INI"
  fi
}

set_misc host_whitelist "$HOST_WHITELIST"
if [ -n "$SABNZBD_API_KEY" ]; then
  set_misc api_key "$SABNZBD_API_KEY"
fi
