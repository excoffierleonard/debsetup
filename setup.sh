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

# Function to check if a user exists
user_exists() {
    id "$1" &>/dev/null
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

# Ask for new user to create or use existing user
NEW_USER=$(prompt_with_default "Enter new username to create or an existing username to configure" "")

if user_exists "$NEW_USER"; then
    echo "User $NEW_USER already exists."
else
    echo "Creating new user $NEW_USER..."
    adduser --disabled-password --gecos "" "$NEW_USER"
    echo "User $NEW_USER created."
fi

# Add new user to sudoers if desired
ADD_TO_SUDOERS=$(prompt_with_default "Do you want to add $NEW_USER to sudoers? (y/n)" "y")
if [[ "$ADD_TO_SUDOERS" == "y" ]]; then
    usermod -aG sudo "$NEW_USER"
    echo "User $NEW_USER added to sudoers."
fi

# Ask for SSH public key for the new user
SSH_KEY=$(prompt_with_default "Enter SSH public key for $NEW_USER or leave blank to disable password and PAM auth" "")
if [[ -n "$SSH_KEY" ]]; then
    mkdir -p /home/"$NEW_USER"/.ssh
    echo "$SSH_KEY" > /home/"$NEW_USER"/.ssh/authorized_keys
    chown -R "$NEW_USER":"$NEW_USER" /home/"$NEW_USER"/.ssh
else
    echo "No SSH key provided. Ensuring $NEW_USER cannot login with password..."
    passwd -d "$NEW_USER"
    passwd -l "$NEW_USER"
fi

# Choose which utilities to install
INSTALL_ZFS=$(prompt_with_default "Do you want to install ZFS utilities? (y/n)" "y")
INSTALL_LIBVIRT=$(prompt_with_default "Do you want to install virtualization utilities (libvirt, QEMU)? (y/n)" "y")
INSTALL_DOCKER=$(prompt_with_default "Do you want to install Docker? (y/n)" "y")
INSTALL_VPN=$(prompt_with_default "Do you want to setup Wireguard VPN? (y/n)" "y")

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
apt install -y sudo neovim git curl wget mc ufw fail2ban wireguard ffmpeg tmux btop ncdu iftop rclone rsync tree neofetch cpufetch zsh cmatrix fzf exa tldr ripgrep qrencode nginx certbot npm mariadb-server zip \
               zsh-syntax-highlighting zsh-autosuggestions \
               linux-headers-amd64 zfsutils-linux \
               --no-install-recommends qemu-system libvirt-clients libvirt-daemon-system virtinst

# Setup Zsh for root and new user
setup_zsh() {
    echo "Setting up zsh..."
    curl -o /etc/skel/.zshrc https://git.jisoonet.com/el/debsetup/-/raw/main/.zshrc
    chmod 644 /etc/skel/.zshrc
    cp /etc/skel/.zshrc /root/
    cp /etc/skel/.zshrc /home/"$NEW_USER"/
    chown "$NEW_USER":"$NEW_USER" /home/"$NEW_USER"/.zshrc
    chsh -s /bin/zsh root
    chsh -s /bin/zsh "$NEW_USER"
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
if [[ "$INSTALL_VPN" == "y" ]]; then
    setup_wireguard
fi

# Get newpeer.sh script
setup_newpeer() {
    echo "Downloading and setting up the newpeer.sh script for Wireguard..."
    curl -o /etc/wireguard/newpeer.sh https://git.jisoonet.com/el/debsetup/-/raw/main/newpeer.sh
    sed -i "s/ENDPOINT/$ENDPOINT/g" /etc/wireguard/newpeer.sh
    sed -i "s/WIREGUARD_PORT/$WIREGUARD_PORT/g" /etc/wireguard/newpeer.sh
}
if [[ "$INSTALL_VPN" == "y" ]]; then
    setup_newpeer
fi

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
if [[ "$INSTALL_DOCKER" == "y" ]]; then
    setup_docker
fi

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

# Install ZFS utilities if selected
if [[ "$INSTALL_ZFS" == "y" ]]; then
    echo "Installing ZFS utilities..."
    apt install -y zfsutils-linux
fi

# Install virtualization utilities if selected
if [[ "$INSTALL_LIBVIRT" == "y" ]]; then
    echo "Installing virtualization utilities..."
    apt install -y qemu-system libvirt-clients libvirt-daemon-system virtinst
fi

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

# Recap
echo "Setup completed with the following configuration:"
echo "Hostname: $HOSTNAME"
echo "WAN Interface: $WAN_INTERFACE"
echo "Endpoint: $ENDPOINT"
echo "SSH Port: $SSH_PORT"
echo "Wireguard Port: $WIREGUARD_PORT"
echo "New User: $NEW_USER"
echo "Added User to sudoers: $ADD_TO_SUDOERS"
echo "Installed ZFS: $INSTALL_ZFS"
echo "Installed Virtualization Utilities: $INSTALL_LIBVIRT"
echo "Installed Docker: $INSTALL_DOCKER"
echo "Set up Wireguard: $INSTALL_VPN"
echo "Please reboot your server."

echo "Basic setup completed. Please reboot your server."