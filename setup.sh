#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Checks for Internet Connectivity
if ! ping -c1 1.1.1.1 &>/dev/null; then
    echo "No internet connection detected. Please check your network."
    exit 1
fi

# Get the network interface used for internet connectivity
DEFAULT_ROUTE=$(ip route get 1.1.1.1)
WAN_INTERFACE=$(echo $DEFAULT_ROUTE | grep -oP 'dev \K\S+')
echo "Detected $WAN_INTERFACE as the WAN facing interface"

# Choose the WAN Endpoint of the server
echo "Enter the public IP adress / Domain Name pointing to that IP, of the server:"
read ENDPOINT
echo "You have selected $ENDPOINT as the server WAN's Endpoint"

# Choose SSH port
echo "Enter the SSH port you wish to use (default 22):"
read SSH_PORT
if [ -z "$SSH_PORT" ]; then
    SSH_PORT=22
fi
echo "You have selected port $SSH_PORT for SSH"

# Choose Wireguard VPN port
echo "Enter the Wireguard VPN port you wish to use (default 51820):"
read WIREGUARD_PORT
if [ -z "$WIREGUARD_PORT" ]; then
    WIREGUARD_PORT=51820
fi
echo "You have selected port $WIREGUARD_PORT for Wireguard"

# Begining of Setup
echo "Begining of Setup..."
export DEBIAN_FRONTEND=noninteractive

# Update and Upgrade
echo "Updating and upgrading your system..."
apt update && apt full-upgrade -y

# Install basic tools
echo "Installing basic tools..."
apt install -y sudo neovim git curl wget mc ufw fail2ban wireguard ffmpeg tmux btop ncdu iftop rclone rsync tree neofetch cpufetch zsh cmatrix fzf exa

# Make zsh default shell and place .zshrc in common location
echo "Setting up zsh..."
curl -o /etc/skel/.zshrc https://git.jisoonet.com/el/debsetup/-/raw/main/.zshrc
chmod 644 /etc/skel/.zshrc
chsh -s /bin/zsh

# Wireguard Setup
echo "Setting up Wireguard..."
umask 077
wg genkey > /etc/wireguard/privatekey
wg pubkey < /etc/wireguard/privatekey > /etc/wireguard/publickey
sed -i "s|PRIVATE_KEY|$(cat /etc/wireguard/privatekey)|g" /etc/wireguard/wg0.conf
sed -i "s|WAN_INTERFACE|$WAN_INTERFACE|g" /etc/wireguard/wg0.conf
sed -i "s|WIREGUARD_PORT|$WIREGUARD_PORT|g" /etc/wireguard/wg0.conf
sed -i '/^#net.ipv4.ip_forward=1/s/^#//' /etc/sysctl.conf
sysctl -p
wg-quick up wg0
systemctl enable wg-quick@wg0.service
umask 022

# Get newpeer.sh script
echo "Downloading and setting up the newpeer.sh script for Wireguard..."
curl -o /etc/wireguard/newpeer.sh https://git.jisoonet.com/el/debsetup/-/raw/main/newpeer.sh?inline=false
sed -i "s/ENDPOINT/$ENDPOINT/g" /etc/wireguard/newpeer.sh
sed -i "s/WIREGUARD_PORT/$WIREGUARD_PORT/g" /etc/wireguard/newpeer.sh

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
ufw allow $WIREGUARD_PORT/udp
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
