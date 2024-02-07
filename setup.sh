#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Update and Upgrade
echo "Updating and upgrading your system..."
apt update && apt full-upgrade -y

# Install basic tools
echo "Installing basic tools..."
apt install -y sudo vim git curl wget ufw fail2ban wireguard ffmpeg tmux htop ncdu iftop rclone rsync tree

# Install ZFS
echo "Installing ZFS..." 
apt install -y linux-headers-amd64
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

# Setup UFW (Uncomplicated Firewall)
# echo "Setting up UFW..."
# ufw allow OpenSSH
# ufw enable

# Secure SSH
echo "Securing SSH..."
sed -i 's/#Port 22/Port 422/g' /etc/ssh/sshd_config # Change SSH port to 422
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/g' /etc/ssh/sshd_config
systemctl restart ssh

# Fail2Ban
# echo "Setting up Fail2Ban..."
# cp /etc/fail2ban/jail.{conf,local}
# systemctl enable fail2ban
# systemctl start fail2ban

echo "Removing unnecessary packages..."
apt autoremove -y

echo "Basic setup completed. Please reboot your server."
