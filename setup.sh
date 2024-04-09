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
if [ "$(id -u)" != "0" ]; then
    echo "Checking for system updates..."
    if id -nG "$USER" | grep -qw "sudo\|admin"; then
        sudo apt update &>/dev/null
        echo "Packages list updated."
    fi
    UPDATES_AVAILABLE=$(apt list --upgradable 2>/dev/null | wc -l)
    if [ "$UPDATES_AVAILABLE" -gt 1 ]; then
        echo "Updates available: $(($UPDATES_AVAILABLE-1))"
    else 
        echo "Your system is up to date."
    fi
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

# Backups
echo "Backing up config files..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.backup

# Setup UFW (Uncomplicated Firewall)
echo "Setting up UFW..."
ufw allow $SSH_PORT/tcp
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

unset DEBIAN_FRONTEND

echo "Basic setup completed. Please reboot your server."
