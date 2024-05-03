#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Checks for Internet Connectivity
if ! ping -c1 google.com &>/dev/null; then
    echo "No internet connection detected. Please check your network."
    exit 1
fi

# Choose SSH port
echo "Enter the SSH port you wish to use:"
read SSH_PORT
echo "You have selected port $SSH_PORT for SSH"

# Choose network interface that connects to WAN
echo "Enter the WAN interface name (usually the #2 when entering [ip a]):"
read OUR_INTERFACE
echo "You have selected $OUR_INTERFACE as a WAN facing interface"

# Choose
echo "Enter the public IP adress / domain name of the server:"
read ENDPOINT
echo "You have selected $ENDPOINT as the server WAN's Endpoint"

export DEBIAN_FRONTEND=noninteractive

# Update and Upgrade
echo "Updating and upgrading your system..."
apt update && apt full-upgrade -y

# Install basic tools
echo "Installing basic tools..."
apt install -y sudo neovim git curl wget mc ufw fail2ban wireguard ffmpeg tmux htop ncdu iftop rclone rsync tree neofetch cpufetch zsh

# Add Neofetch to /etc/bash.bashrc with a conditional statement
echo "Setting up Neofetch..."
echo '
# Display Neofetch output for non-root users
if [ "$(id -u)" != "0" ]; then
    echo ""
    neofetch
fi
' | sudo tee -a /etc/bash.bashrc >/dev/null

echo "Configuring no-password sudo for 'apt update' command..."
echo "
%sudo ALL=(ALL) NOPASSWD: /usr/bin/apt update
" | sudo EDITOR='tee -a' visudo >/dev/null

echo "Adding update checking..." 
echo '
# Check for system upgrades for non-root users
if [ "$(id -u)" != "0" ]; then
    echo "Checking for system updates..."
    if id -nG "$USER" | grep -qw "sudo\|admin"; then
        sudo apt update &>/dev/null
        echo "Packages list updated."
    fi
    UPGRADES_AVAILABLE=$(apt list --upgradable 2>/dev/null | wc -l)
    if [ "$UPGRADES_AVAILABLE" -gt 1 ]; then
        echo "Upgrades available: $(($UPGRADES_AVAILABLE-1))"
    else 
        echo "Your system is up to date."
    fi
fi
' | sudo tee -a /etc/profile >/dev/null

# Wireguard Setup
echo "Setting up Wireguard"
umask 077
wg genkey > /etc/wireguard/privatekey
wg pubkey < /etc/wireguard/privatekey > /etc/wireguard/publickey

sed -i '/^#net.ipv4.ip_forward=1/s/^#//' /etc/sysctl.conf
sysctl -p

ip link add dev wg0 type wireguard
ip address add dev wg0 10.0.2.1/24
wg set wg0 private-key /etc/wireguard/privatekey
wg set wg0 listen-port 61820

wg showconf wg0 > /etc/wireguard/wg0.conf
echo "Address=10.0.2.1/24" >> /etc/wireguard/wg0.conf
echo "SaveConfig = true" >> /etc/wireguard/wg0.conf

echo "PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $OUR_INTERFACE -j MASQUERADE" >> /etc/wireguard/wg0.conf
echo "PostDOWN = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $OUR_INTERFACE -j MASQUERADE" >> /etc/wireguard/wg0.conf

systemctl enable wg-quick@wg0.service

umask 022

# Install ZFS
echo "Installing ZFS..." 
apt install -y linux-headers-amd64
codename=$(lsb_release -cs);echo "deb http://deb.debian.org/debian $codename-backports main contrib non-free"|sudo tee -a /etc/apt/sources.list && sudo apt update -y
apt install -y -t stable-backports zfsutils-linux

# Install Duplicacy
echo "Installing Duplicacy..."
curl -fsSL https://github.com/gilbertchen/duplicacy/releases/download/v3.2.3/duplicacy_linux_x64_3.2.3 -o /usr/local/bin/duplicacy
chmod +x /usr/local/bin/duplicacy

# Install Docker Engine
echo "Installing Docker Engine..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
rm get-docker.sh

# Installing QEMU, KVM, libvirt and virtinst
echo "Installing QEMU, KVM, libvirt and virtinst..."
apt install -y --no-install-recommends qemu-system libvirt-clients libvirt-daemon-system
apt install -y virtinst

# Backups
echo "Backing up config files..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.backup

# Setup UFW (Uncomplicated Firewall)
echo "Setting up UFW..."
ufw allow $SSH_PORT/tcp
ufw allow 61820/udp
ufw default deny incoming
ufw default allow outgoing
ufw logging on
echo "y" | ufw enable

# Secure SSH
echo "Securing SSH..."
sed -i "s/#Port 22/Port $SSH_PORT/g" /etc/ssh/sshd_config # Change SSH port
sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/g" /etc/ssh/sshd_config
systemctl restart ssh

# Fail2Ban
echo "Setting up Fail2Ban..."
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sed -i "/^\[sshd\]$/,/^\[/ s/port\s*=\s*ssh/port    = $SSH_PORT/g" /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl restart fail2ban

echo "Removing unnecessary packages..."
apt autoremove -y

unset DEBIAN_FRONTEND

echo "Basic setup completed. Please reboot your server."
