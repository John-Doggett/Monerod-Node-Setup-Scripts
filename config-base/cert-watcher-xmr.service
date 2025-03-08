#!/bin/bash

# The Domain Name of the Server
DOMAIN_NAME="DOMAINNAME"
# Directory where Caddy stores certificates
CERT_DIR="/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${DOMAIN_NAME}"
# Directory where monero stores certificates
MONERO_DIR="/var/lib/monero/certificates"
# Interval in seconds to check for changes
POLL_INTERVAL=300

while true; do
    # Paths to certificate and key files
    CERT_KEY="$CERT_DIR/${DOMAIN_NAME}.key"
    MONERO_KEY="$MONERO_DIR/${DOMAIN_NAME}.key"
    CERT_CRT="$CERT_DIR/${DOMAIN_NAME}.crt"
    MONERO_CRT="$MONERO_DIR/${DOMAIN_NAME}.crt"

    # Flag to determine if an update is needed
    UPDATE_NEEDED=false

    # Check if the certificate key exists in CERT_DIR and if an update is needed
    if [ -s "$CERT_KEY" ]; then
        if [ ! -s "$MONERO_KEY" ] || ! cmp -s "$CERT_KEY" "$MONERO_KEY"; then
            echo "Key file update required."
            UPDATE_NEEDED=true
        fi
    fi

    # Check if the certificate crt exists in CERT_DIR and if an update is needed
    if [ -s "$CERT_CRT" ]; then
        if [ ! -s "$MONERO_CRT" ] || ! cmp -s "$CERT_CRT" "$MONERO_CRT"; then
            echo "Certificate file update required."
            UPDATE_NEEDED=true
        fi
    fi

    # If an update is needed, stop monerod, copy files, update ownership, and restart
    if [ "$UPDATE_NEEDED" = true ]; then
        echo "Updating certificates at $(date +"%Y-%m-%d %H:%M:%S"). Restarting monerod."
        systemctl stop monerod

        # Copy updated files
        cp -v "$CERT_KEY" "$MONERO_KEY"
        cp -v "$CERT_CRT" "$MONERO_CRT"

        # Update ownership
        chown -R -v monero:monero "$MONERO_DIR"

        # Restart monerod
        systemctl start monerod
    fi

    # Sleep for the polling interval before checking again
    sleep "$POLL_INTERVAL"
done
