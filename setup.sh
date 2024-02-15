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

# Backups
echo "Backing up config files..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.backup

# Update and Upgrade
echo "Updating and upgrading your system..."
apt update && apt full-upgrade -y

# Install basic tools
echo "Installing basic tools..."
apt install -y sudo neovim git curl wget mc ufw fail2ban wireguard ffmpeg tmux htop ncdu iftop rclone rsync tree neofetch zsh

# Add Neofetch to /etc/bash.bashrc with a conditional statement
echo "Setting up Neofetch"
echo '
# Display Neofetch output for non-root users
if [ "$(id -u)" != "0" ]; then
    echo ""  # Add a blank line for better formatting
    neofetch
fi
' | sudo tee -a /etc/bash.bashrc >/dev/null

# Install ZFS
echo "Installing ZFS..." 
apt install -y linux-headers-amd64
codename=$(lsb_release -cs);echo "deb http://deb.debian.org/debian $codename-backports main contrib non-free"|sudo tee -a /etc/apt/sources.list && sudo apt update
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

# Setup UFW (Uncomplicated Firewall)
echo "Setting up UFW..."
ufw allow 422/tcp
ufw default deny incoming
ufw default allow outgoing
ufw logging on
echo "y" | ufw enable

# Secure SSH
echo "Securing SSH..."
sed -i "s/#Port 22/Port $SSH_PORT/g" /etc/ssh/sshd_config # Change SSH port to 422
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

echo "Basic setup completed. Please reboot your server."
