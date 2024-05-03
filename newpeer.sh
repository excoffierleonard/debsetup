#!/bin/bash

# Check for peer name input
if [ -z "$1" ]
then
    echo "Please provide a peer name."
    exit 1
fi

PEER_NAME=$1

wg-quick down wg0 > /dev/null 2>&1

# Paths to the WireGuard configuration and public key file
WG_CONFIG="/etc/wireguard/wg0.conf"
VPS_PUBLIC_KEY_FILE="/etc/wireguard/publickey"
PEER_RECORDS="/etc/wireguard/peer_records.txt"

# Fetch the VPS public key
VPS_PUBLIC_KEY=$(cat $VPS_PUBLIC_KEY_FILE)

# Extract the last used IP address, find the highest, and calculate the next IP
LAST_IP_HEX=$(grep "AllowedIPs" $WG_CONFIG | awk '{print $NF}' | cut -d '/' -f 1 | awk -F "." '{ printf "0x%02X%02X%02X%02X\n", $1,$2,$3,$4 }' | sort -u | tail -1)
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

# Record peer details externally
echo "Peer Name: $PEER_NAME, PublicKey: $NEW_PUB_KEY, IP: $NEW_IP" >> $PEER_RECORDS

# Generate QR code for the new peer setup
NEW_PEER_CONFIG="[Interface]
PrivateKey = $NEW_PRIV_KEY
Address = $NEW_IP
DNS = 1.1.1.1
[Peer]
PublicKey = $VPS_PUBLIC_KEY
Endpoint = ENDPOINT_PLACEHOLDER:61820
AllowedIPs = 0.0.0.0/0"

echo ""
echo "$NEW_PEER_CONFIG" | qrencode -o - -t UTF8

# Restart WireGuard to apply changes
wg-quick up wg0 > /dev/null 2>&1

echo ""
echo "New WireGuard peer '"$1"' added, and configuration QR code generated."