#!/bin/bash

# Check for peer name input
if [ -z "$1" ]
then
    echo "Please provide a peer name."
    exit 1
fi

PEER_NAME=$1
PEER_CONFIG_FILE="/etc/wireguard/peers/${PEER_NAME}.conf"

wg-quick down wg0 > /dev/null 2>&1

# Paths to the WireGuard configuration, public key file, and peer records
WG_CONFIG="/etc/wireguard/wg0.conf"
VPS_PUBLIC_KEY_FILE="/etc/wireguard/publickey"
PEER_RECORDS="/etc/wireguard/peer_records.txt"

# Ensure peer configurations directory exists
mkdir -p /etc/wireguard/peers

# Fetch the VPS public key
VPS_PUBLIC_KEY=$(cat $VPS_PUBLIC_KEY_FILE)

# Extract the last used IP address, find the highest, and calculate the next IP
LAST_IP_HEX=$(grep "AllowedIPs" $WG_CONFIG | awk '{print $NF}' | cut -d '/' -f 1 | awk -F "." '{ printf "0x%02X%02X%02X%02X\n", $1,$2,$3,$4 }' | sort -u | tail -1)
# If no last IP address is found, use the Address parameter from the [Interface] section
if [ -z "$LAST_IP_HEX" ]; then
    LAST_IP_HEX=$(grep "Address" $WG_CONFIG | awk '{print $NF}' | cut -d '/' -f 1 | awk -F "." '{ printf "0x%02X%02X%02X%02X\n", $1,$2,$3,$4 }')
fi
LAST_IP_DEC=$((LAST_IP_HEX))
NEXT_IP_DEC=$(($LAST_IP_DEC + 1))
NEXT_IP=$(printf "%d.%d.%d.%d" $(($NEXT_IP_DEC>>24&255)) $(($NEXT_IP_DEC>>16&255)) $(($NEXT_IP_DEC>>8&255)) $(($NEXT_IP_DEC&255)))

# Network config adjustments
NEW_IP="$NEXT_IP/32"

# Generate keys for the new peer
NEW_PRIV_KEY=$(wg genkey)
NEW_PUB_KEY=$(echo $NEW_PRIV_KEY | wg pubkey)

# Append new peer configuration to wg0.conf
echo "\n[Peer]\nPublicKey = $NEW_PUB_KEY\nAllowedIPs = $NEW_IP" >> $WG_CONFIG

# Record peer details with private key externally
echo "Peer Name: $PEER_NAME, PublicKey: $NEW_PUB_KEY, PrivateKey: $NEW_PRIV_KEY, IP: $NEW_IP" >> $PEER_RECORDS

# Change the permissions of peer_records.txt to be read-only by root
chmod 600 $PEER_RECORDS
chown root:root $PEER_RECORDS

# Generate QR code for the new peer setup
NEW_PEER_CONFIG="[Interface]
PrivateKey = $NEW_PRIV_KEY
Address = $NEW_IP
DNS = 1.1.1.1
[Peer]
PublicKey = $VPS_PUBLIC_KEY
Endpoint = ENDPOINT:WIREGUARD_PORT
AllowedIPs = 0.0.0.0/0"

echo "$NEW_PEER_CONFIG" | qrencode -o - -t UTF8

# Save the configuration to a file for PC usage
echo "$NEW_PEER_CONFIG" > $PEER_CONFIG_FILE

# Restart WireGuard to apply changes
wg-quick up wg0 > /dev/null 2>&1

echo ""
echo "New WireGuard peer '"$1"' added, configuration QR code generated, and .conf file stored at ${PEER_CONFIG_FILE}."