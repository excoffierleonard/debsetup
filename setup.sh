#!/bin/bash

# Ensure the script is run as root
if [[ "$(id -u)" != "0" ]]; then
   echo "This script must be run as root" >&2
   exit 1
fi

# Check for Internet connectivity
if ! ping -c1 1.1.1.1 &>/dev/null; then
    echo "No internet connection detected. Please check your network."
    exit 1
fi

# Function to prompt for input with a default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var
    read -p "$prompt (press Enter to choose $default): " var
    echo "${var:-$default}"
}

# Choose the network interface used for internet connectivity
DEFAULT_ROUTE=$(ip route get 1.1.1.1)
WAN_INTERFACE_DEFAULT=$(echo $DEFAULT_ROUTE | grep -oP 'dev \K\S+')
WAN_INTERFACE=$(prompt_with_default "Enter the WAN Interface you would like to use" "$WAN_INTERFACE_DEFAULT")
echo "You have selected $WAN_INTERFACE as the server WAN's Interface"

# Choose the WAN Endpoint of the server
public_ip=$(wget -qO- http://ipinfo.io/ip)
ENDPOINT=$(prompt_with_default "Enter the public IP address / Domain Name of the server" "$public_ip")
echo "You have selected $ENDPOINT as the server WAN's Endpoint"

# Choose Hostname
current_hostname=$(hostname)
HOSTNAME=$(prompt_with_default "Enter system Hostname you wish to use" "$current_hostname")
echo "You have selected $HOSTNAME as the server Hostname"

# Choose SSH port
SSH_PORT=$(prompt_with_default "Enter the SSH port you wish to use" "22")
echo "You have selected port $SSH_PORT for SSH"

# Choose Wireguard VPN port
WIREGUARD_PORT=$(prompt_with_default "Enter the Wireguard VPN port you wish to use" "51820")
echo "You have selected port $WIREGUARD_PORT for Wireguard"

# Begin Setup
echo "Beginning of Setup..."
export DEBIAN_FRONTEND=noninteractive

# Update and upgrade system
echo "Updating and upgrading your system..."
apt update && apt full-upgrade -y

# Change the system hostname
echo "Changing the system hostname..."
hostnamectl set-hostname "$HOSTNAME"

# Install packages
echo "Installing necessary packages..."
codename=$(lsb_release -cs)
echo "deb http://deb.debian.org/debian $codename-backports main contrib non-free" | tee -a /etc/apt/sources.list
apt update -y
apt install -y sudo neovim git curl wget mc ufw fail2ban wireguard ffmpeg tmux btop ncdu iftop rclone rsync tree neofetch cpufetch zsh cmatrix fzf exa tldr ripgrep qrencode nginx certbot \
               zsh-syntax-highlighting zsh-autosuggestions \
               linux-headers-amd64 zfsutils-linux \
               --no-install-recommends qemu-system libvirt-clients libvirt-daemon-system virtinst

# Setup Zsh
setup_zsh() {
    echo "Setting up zsh..."
    curl -o /etc/skel/.zshrc https://git.jisoonet.com/el/debsetup/-/raw/main/.zshrc
    chmod 644 /etc/skel/.zshrc
    cp /etc/skel/.zshrc /root/
    chsh -s /bin/zsh
}
setup_zsh

# Changing login page formatting, removing default MOTDs
setup_login_page() {
    echo "Changing login page formatting, removing default MOTDs..."
    cp /etc/issue /etc/issue.backup
    cp /etc/motd /etc/motd.backup
    tar -czf /etc/update-motd.d_backup.tar.gz /etc/update-motd.d
    echo -n "" > /etc/issue
    echo -n "" > /etc/motd
    chmod -x /etc/update-motd.d/*
}
setup_login_page

# Wireguard Setup
setup_wireguard() {
    echo "Setting up Wireguard..."
    curl -o /etc/wireguard/wg0.conf https://git.jisoonet.com/el/debsetup/-/raw/main/wg0.conf
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
}
setup_wireguard

# Get newpeer.sh script
setup_newpeer() {
    echo "Downloading and setting up the newpeer.sh script for Wireguard..."
    curl -o /etc/wireguard/newpeer.sh https://git.jisoonet.com/el/debsetup/-/raw/main/newpeer.sh
    sed -i "s/ENDPOINT/$ENDPOINT/g" /etc/wireguard/newpeer.sh
    sed -i "s/WIREGUARD_PORT/$WIREGUARD_PORT/g" /etc/wireguard/newpeer.sh
}
setup_newpeer

# Install Duplicacy
setup_duplicacy() {
    echo "Installing Duplicacy..."
    curl -fsSL https://github.com/gilbertchen/duplicacy/releases/download/v3.2.3/duplicacy_linux_x64_3.2.3 -o /usr/local/bin/duplicacy
    chmod +x /usr/local/bin/duplicacy
}
setup_duplicacy

# Install Docker Engine
setup_docker() {
    echo "Installing Docker Engine..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
}
setup_docker

# Backup configurations
backup_configs() {
    echo "Backing up config files..."
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.backup
}
backup_configs

# Setup UFW (Uncomplicated Firewall)
setup_ufw() {
    echo "Setting up UFW..."
    ufw allow "$SSH_PORT/tcp"
    ufw allow "$WIREGUARD_PORT/udp"
    ufw default deny incoming
    ufw default allow outgoing
    ufw logging on
    echo "y" | ufw enable
}
setup_ufw

# Secure SSH
secure_ssh() {
    echo "Securing SSH..."
    sed -i "s/#Port 22/Port $SSH_PORT/g" /etc/ssh/sshd_config
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/g" /etc/ssh/sshd_config
    systemctl restart ssh
}
secure_ssh

# Setup Fail2Ban
setup_fail2ban() {
    echo "Setting up Fail2Ban..."
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    sed -i "/^\[sshd\]$/,/^\[/ s/port\s*=\s*ssh/port    = $SSH_PORT/g" /etc/fail2ban/jail.local
    systemctl enable fail2ban
    systemctl restart fail2ban
}
setup_fail2ban

# Change time zone
change_timezone() {
    echo "Changing time zone to EST"
    timedatectl set-timezone America/New_York
    echo "Time zone changed to EST"
}
change_timezone

# Remove unnecessary packages
cleanup() {
    echo "Removing unnecessary packages..."
    apt autoremove -y
    unset DEBIAN_FRONTEND
}
cleanup

echo "Basic setup completed. Please reboot your server."
