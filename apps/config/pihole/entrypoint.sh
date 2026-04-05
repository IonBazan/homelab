#!/bin/bash

# Ensure environment variables are set, fallback to defaults if not
DOMAIN=${CUSTOM_DOMAIN:-"mydomain.com"}
IP=${CUSTOM_IP:-"192.168.18.102"}

# Write the dnsmasq config file
cat > /etc/dnsmasq.d/02-custom.conf <<EOF
# Generated from environment variables
address=/$DOMAIN/$IP
EOF

# Execute the original Pi-hole entrypoint
exec start.sh
