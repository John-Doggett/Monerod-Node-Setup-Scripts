#!/bin/bash

# The Domain Name of the Server
DOMAIN_NAME="DOMAINNAME"
# Directory where Caddy stores certificates
CERT_DIR="/var/lib/caddy/.local/share/caddy/certificates/acme-v02.api.letsencrypt.org-directory/${DOMAIN_NAME}"
# Directory where monero stores certificates
MONERO_DIR="/var/lib/monero/certificates"
# Interval in seconds to check for changes
POLL_INTERVAL=60

while true; do
    # Store the last modification time
    LAST_MOD_TIME=$(cat ${MONERO_DIR}/last-update)

    # Use inotifywait with a timeout to check for changes
    inotifywait -t "$POLL_INTERVAL" -e modify -e create -e delete --quiet "$CERT_DIR"

    # Get the current modification time of the directory
    CURRENT_MOD_TIME=$(stat -c %Y "$CERT_DIR")

    # Compare with the last known modification time
    if [ "$CURRENT_MOD_TIME" -ne "$LAST_MOD_TIME" ]; then
        echo "Certificate change detected at $(date +"%Y-%m-%d %H:%M:%S"). Restarting monerod and updating certificates."

        # Stop monerod
        systemctl stop monerod

        # Update the last known modification time
        LAST_MOD_TIME=$CURRENT_MOD_TIME
        echo $LAST_MOD_TIME > ${MONERO_DIR}/last-update

        # Copy over files
        cp -v $CERT_DIR/${DOMAIN_NAME}.crt $MONERO_DIR
        cp -v $CERT_DIR/${DOMAIN_NAME}.key $MONERO_DIR

        # Update chown
        chown -R -v monero:monero $MONERO_DIR

        # Start monerod
        systemctl start monerod
    fi
done
