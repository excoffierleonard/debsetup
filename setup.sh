#!/bin/bash

# TODO: Add a one click option for full defaults
# TODO: Output a recap before doing modifications and at the end of script
# TODO: Create a dotfile repo for debian server
# TODO: Maybe add option to pull usefull docker image, vms, isos, files, etc...
# TODO: Maybe add a default for SSH keys consider public or pricvate rpo of public keys.
# TODO: Explicitly say that root password will be disabled and ssh key will be used
# TODO: Add checks so script is run twice with no problem
# TODO: Maybe do not force zsh config for all users
# TODO: Make default usernam dynamic
# TODO: Add more granular error handling
# TODO: Add trap commands to ensure any temporary files (like downloaded scripts) are deleted even if the script exits prematurely.
# TODO: ADD option for timezone selection
# FIX : ADD default zfs and virt and docker to user input
# TODO: Maybe centralize rms of downloads

# External links centralized
DOCKER_INSTALL_SCRIPT="https://get.docker.com"
DUPLICACY_RELEASE="https://github.com/gilbertchen/duplicacy/releases/download/v3.2.3/duplicacy_linux_x64_3.2.3"
LAZYDOCKER_INSTALL_SCRIPT="https://raw.githubusercontent.com/upciti/wakemeops/main/assets/install_repository"
LAZYGIT_API="https://api.github.com/repos/jesseduffield/lazygit/releases/latest"
ZSHRC_FILE="https://git.jisoonet.com/el/debsetup/-/raw/main/.zshrc"
WG0_CONF="https://git.jisoonet.com/el/debsetup/-/raw/main/wg0.conf"
NEWPEER_SH="https://git.jisoonet.com/el/debsetup/-/raw/main/newpeer.sh"

# Initial requirement verifications
initial_verification() {
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
}

# Prompt for user inputs
user_input() {
    # Function to prompt for input with a default value
    prompt_with_default() {
        local prompt="$1"
        local default="$2"
        local var
        read -p "$prompt (press Enter to choose $default): " var
        echo "${var:-$default}"
    }

    # Default variables
    DEFAULT_HOSTNAME=$(hostname)
    DEFAULT_SSH_PORT=22
    DEFAULT_USERNAME=el
    DEFAULT_ADD_TO_SUDOERS=y
    DEFAULT_DISABLE_PASSWORD_AUTH=n
    DEFAULT_INSTALL_WG=y
    DEFAULT_WIREGUARD_PORT=51820
    DEFAULT_WAN_INTERFACE=$(ip route get 1.1.1.1 | grep -oP 'dev \K\S+')
    DEFAULT_ENDPOINT=$(wget -qO- http://ipinfo.io/ip)
    
    # Choose Hostname
    read -p "Enter system Hostname you wish to use (press Enter to choose $DEFAULT_HOSTNAME): " HOSTNAME
    HOSTNAME=${HOSTNAME:-$DEFAULT_HOSTNAME}
    echo "You have selected $HOSTNAME as the server Hostname"

    # Choose SSH port
    read -p "Enter the SSH port you wish to use (press Enter to choose $DEFAULT_SSH_PORT): " SSH_PORT
    SSH_PORT=${SSH_PORT:-$DEFAULT_SSH_PORT}
    echo "You have selected port $SSH_PORT for SSH"

    # Create a new user or input an existing user
    read -p "Enter the username of the user you wish to create or use (press Enter to choose $DEFAULT_USERNAME): " USERNAME
    USERNAME=${USERNAME:-$DEFAULT_USERNAME}
    echo "You have selected user $USERNAME"

    # Add new user to sudoers if desired
    read -p "Do you want to add $USERNAME to sudoers? (y/n, press Enter to choose $DEFAULT_ADD_TO_SUDOERS): " ADD_TO_SUDOERS
    ADD_TO_SUDOERS=${ADD_TO_SUDOERS:-$DEFAULT_ADD_TO_SUDOERS}
    echo "You have selected $ADD_TO_SUDOERS to sudoers for $USERNAME"

    # Ask for password if user does not exist
    if ! id "$USERNAME" &>/dev/null; then
        read -sp "Enter password for user $USERNAME (input hidden): " USER_PASSWORD
        echo "Password will be set for $USERNAME"
    fi

    # Ask for SSH key if desired
    read -p "Enter an SSH Authorized Key for $USERNAME (press Enter to skip): " SSH_KEY
    if [[ -n "$SSH_KEY" ]]; then
        echo "SSH key: $SSH_KEY will be set for $USERNAME"
    fi

    # Ask user if they want to disable password authentication
    if [[ -n "$SSH_KEY" ]]; then
        read -p "Do you want to disable password authentication for SSH? (y/n, press Enter to choose $DEFAULT_DISABLE_PASSWORD_AUTH): " DISABLE_PASSWORD_AUTH
        DISABLE_PASSWORD_AUTH=${DISABLE_PASSWORD_AUTH:-$DEFAULT_DISABLE_PASSWORD_AUTH}
        echo "You have selected $DISABLE_PASSWORD_AUTH to disable password option for SSH"
    fi

    # Wireguard Installation
    read -p "Do you want to install Wireguard? (y/n, press Enter to choose $DEFAULT_INSTALL_WG): " INSTALL_WG
    INSTALL_WG=${INSTALL_WG:-$DEFAULT_INSTALL_WG}
    echo "You have selected $INSTALL_WG for Wireguard installation"

    if [[ "$INSTALL_WG" == "y" ]]; then
        # Choose the network interface used for internet connectivity
        read -p "Enter the WAN Interface you would like to use for Wireguard (press Enter to choose $DEFAULT_WAN_INTERFACE): " WAN_INTERFACE
        WAN_INTERFACE=${WAN_INTERFACE:-$DEFAULT_WAN_INTERFACE}
        echo "You have selected $WAN_INTERFACE as the server WAN's Interface for Wireguard"

        # Choose the WAN Endpoint of the server
        read -p "Enter the public IP address / Domain Name of the server to be used for Wireguard (press Enter to choose $DEFAULT_ENDPOINT): " ENDPOINT
        ENDPOINT=${ENDPOINT:-$DEFAULT_ENDPOINT}
        echo "You have selected $ENDPOINT as the server WAN's Endpoint for Wireguard"

        # Choose Wireguard VPN port
        read -p "Enter the Wireguard VPN port you wish to use (press Enter to choose $DEFAULT_WIREGUARD_PORT): " WIREGUARD_PORT
        WIREGUARD_PORT=${WIREGUARD_PORT:-$DEFAULT_WIREGUARD_PORT}
        echo "You have selected port $WIREGUARD_PORT for Wireguard"
    fi

    # ZFS Installation
    read -p "Do you want to install ZFS? (y/n, press Enter to choose 'y'): " INSTALL_ZFS
    INSTALL_ZFS=${INSTALL_ZFS:-y}
    echo "You have selected $INSTALL_ZFS for ZFS installation"

    # Virtualization Installation
    read -p "Do you want to install Virtualization packages? (y/n, press Enter to choose 'y'): " INSTALL_VIRT
    INSTALL_VIRT=${INSTALL_VIRT:-y}
    echo "You have selected $INSTALL_VIRT for Virtualization packages installation"

    # Docker Installation
    read -p "Do you want to install Docker Engine? (y/n, press Enter to choose 'y'): " INSTALL_DOCKER
    INSTALL_DOCKER=${INSTALL_DOCKER:-y}
    echo "You have selected $INSTALL_DOCKER for Docker Engine installation"

    # Confirm user choices
    echo ""
    echo "You have selected the following options:"
    echo "Hostname: $HOSTNAME"
    echo "SSH Port: $SSH_PORT"
    echo "Username: $USERNAME"
    echo "Add $USERNAME to sudoers: $ADD_TO_SUDOERS"
    if [[ -n "$SSH_KEY" ]]; then
        echo "SSH Key: $SSH_KEY"
    fi
    if [[ -n "$SSH_KEY" ]]; then
        echo "Disable Password Authentication: $DISABLE_PASSWORD_AUTH"
    fi
    echo "Install Wireguard: $INSTALL_WG"
    if [[ "$INSTALL_WG" == "y" ]]; then
        echo "WAN Interface: $WAN_INTERFACE"
        echo "WAN Endpoint: $ENDPOINT"
        echo "Wireguard Port: $WIREGUARD_PORT"
    fi
    echo "Install ZFS: $INSTALL_ZFS"
    echo "Install Virtualization packages: $INSTALL_VIRT"
    echo "Install Docker Engine: $INSTALL_DOCKER"
    read -p "Do you want to proceed with these settings? (y/n): " PROCEED
    if [[ "$PROCEED" != "y" ]]; then
        echo "Exiting script..."
        exit 1
    fi
}

# Initial script options
initial_script_options() {
    echo "Beginning of Setup..."
    set -e
    export DEBIAN_FRONTEND=noninteractive
}

# Update and upgrade system
full_upgrade() {
    echo "Updating and upgrading your system..."
    apt update
    apt full-upgrade -y
}

# Create the user if necessary and set the password
create_user() {
    if ! id "$USERNAME" &>/dev/null; then
        echo "Creating user $USERNAME..."
        useradd -m "$USERNAME"
        echo "$USERNAME:$USER_PASSWORD" | chpasswd
        echo "User $USERNAME created with specified password."
    fi
}

# Change the system hostname
change_hostname() {
    echo "Changing the system hostname..."
    hostnamectl set-hostname "$HOSTNAME"
}

# Change the system time zone
change_timezone() {
    echo "Changing time zone to EST..."
    timedatectl set-timezone America/New_York
}

# Changing login page formatting, removing default MOTDs
change_login_page() {
    echo "Changing login page formatting, removing default MOTDs..."
    cp /etc/issue /etc/issue.backup
    cp /etc/motd /etc/motd.backup
    tar -czf /etc/update-motd.d_backup.tar.gz /etc/update-motd.d
    echo -n "" > /etc/issue
    echo -n "" > /etc/motd
    chmod -x /etc/update-motd.d/*
}

# Secure SSH
secure_ssh() {
    echo "Securing SSH..."
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    sed -i "s/#Port 22/Port $SSH_PORT/g" /etc/ssh/sshd_config
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/g" /etc/ssh/sshd_config
    if [[ -n "$SSH_KEY" ]]; then
        echo "Adding SSH key to $USERNAME's authorized keys..."
        mkdir -p "/home/$USERNAME/.ssh"
        echo "$SSH_KEY" > "/home/$USERNAME/.ssh/authorized_keys"
        chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
        chmod 700 "/home/$USERNAME/.ssh"
        chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
        echo "SSH key added to $USERNAME's authorized keys."
    fi
    if [[ "$DISABLE_PASSWORD_AUTH" == "y" ]]; then
        echo "Disabling password authentication for SSH..."
        sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
        systemctl restart ssh
        echo "Password authentication disabled for SSH."
    fi
    systemctl restart ssh
}

# Install default repository tools (session based)
install_defaultrepo_tools() {
    echo "Installing tools..."
    apt install -y sudo neovim git curl wget mc ffmpeg tmux btop ncdu iftop rclone rsync tree neofetch cpufetch cmatrix fzf exa tldr ripgrep qrencode certbot npm zip unzip htop zsh zsh-syntax-highlighting zsh-autosuggestions
}

# Centralize necessary downloads based on user input
centralize_downloads() {
    echo "Centralizing necessary downloads based on choices..."
    mkdir -p /downloads

    # Always download Zsh configuration and Wireguard configuration files
    curl -o /downloads/.zshrc $ZSHRC_FILE
    curl -o /downloads/wg0.conf $WG0_CONF
    curl -o /downloads/newpeer.sh $NEWPEER_SH

    # Conditional downloads based on user selections

    # If Lazygit is installed (part of tools), download it
    echo "Preparing to download Lazygit..."
    LAZYGIT_VERSION=$(curl -s $LAZYGIT_API | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo /downloads/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"

    # If Duplicacy is needed (part of tools), download it
    echo "Preparing to download Duplicacy..."
    curl -fsSL $DUPLICACY_RELEASE -o /downloads/duplicacy

    # If Docker is to be installed, download Docker script and Lazydocker
    if [[ "$INSTALL_DOCKER" == "y" ]]; then
        echo "Preparing to download Docker installation script and Lazydocker..."
        curl -fsSL $DOCKER_INSTALL_SCRIPT -o /downloads/get-docker.sh
        curl -sSL $LAZYDOCKER_INSTALL_SCRIPT -o /downloads/lazydocker_install.sh
    fi
}

# Install Lazygit
install_lazygit() {
    tar xf /downloads/lazygit.tar.gz -C /downloads/ lazygit
    install /downloads/lazygit /usr/local/bin
    rm /downloads/lazygit.tar.gz
    rm /downloads/lazygit
}

# Install Duplicacy
install_duplicacy() {
    echo "Installing Duplicacy..."
    cp /downloads/duplicacy /usr/local/bin/
    chmod +x /usr/local/bin/duplicacy
    rm /downloads/duplicacy
}

# Install system services (system background processes)
install_system_services() {
    echo "Installing system services..."
    apt install -y ufw fail2ban wireguard
}

# Install ZFS
install_zfs() {
    echo "Installing ZFS..."
    codename=$(lsb_release -cs)
    echo "deb http://deb.debian.org/debian $codename-backports main contrib non-free" | tee -a /etc/apt/sources.list
    apt update
    apt install -y linux-headers-amd64 zfsutils-linux
}

# Install Virtualization packages
install_virt() {
    echo "Installing Virtualization packages..."
    apt install -y qemu-system libvirt-clients libvirt-daemon-system virtinst
}

# Install Lazydocker
install_lazydocker() {
    echo "Installing Lazydocker..."
    bash /downloads/lazydocker_install.sh
    apt install lazydocker
    rm /downloads/lazydocker_install.sh
}

# Install Docker Engine
install_docker() {
    echo "Installing Docker Engine..."
    sh /downloads/get-docker.sh
    rm /downloads/get-docker.sh
}

# Setup User
setup_user() {
    if [[ "$ADD_TO_SUDOERS" == "y" ]]; then
        usermod -aG sudo "$USERNAME"
        echo "User $USERNAME added to sudoers."
    fi
}

# Setup Zsh
setup_zsh() {
    echo "Setting up zsh..."
    cp /downloads/.zshrc /etc/skel/
    chmod 644 /etc/skel/.zshrc
    cp /etc/skel/.zshrc /root/
    chsh -s /bin/zsh root
    cp /etc/skel/.zshrc /home/$USERNAME/
    chown $USERNAME:$USERNAME /home/$USERNAME/.zshrc
    chsh -s /bin/zsh $USERNAME
    rm /downloads/.zshrc
}

# Setup UFW (Uncomplicated Firewall)
setup_ufw() {
    echo "Setting up UFW..."
    ufw allow "$SSH_PORT/tcp"
    if [[ "$INSTALL_WG" == "y" ]]; then
        ufw allow "$WIREGUARD_PORT/udp"
    fi
    ufw default deny incoming
    ufw default allow outgoing
    ufw logging on
    echo "y" | ufw enable
}

# Setup Fail2Ban
setup_fail2ban() {
    echo "Setting up Fail2Ban..."
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.backup
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    sed -i "/^\[sshd\]$/,/^\[/ s/port\s*=\s*ssh/port    = $SSH_PORT/g" /etc/fail2ban/jail.local
    systemctl enable fail2ban
    systemctl restart fail2ban
}

# Wireguard Setup
setup_wireguard() {
    echo "Setting up Wireguard..."
    cp /downloads/wg0.conf /etc/wireguard/
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
    rm /downloads/wg0.conf
}

# Get newpeer.sh script
setup_newpeer() {
    echo "Downloading and setting up the newpeer.sh script for Wireguard..."
    cp /downloads/newpeer.sh /etc/wireguard/
    sed -i "s/ENDPOINT/$ENDPOINT/g" /etc/wireguard/newpeer.sh
    sed -i "s/WIREGUARD_PORT/$WIREGUARD_PORT/g" /etc/wireguard/newpeer.sh
    rm /downloads/newpeer.sh
}

# End of script actions
cleanup() {
    echo "End of script actions..."
    apt update
    apt full-upgrade -y
    apt autoremove -y
    rm debsetup.sh
    unset DEBIAN_FRONTEND
}

# Recap of script actions
recap() {
    echo "Recap of script actions..."
    echo "Hostname: $HOSTNAME"
    echo "SSH Port: $SSH_PORT"
    echo "Username: $USERNAME"
    echo "Add $USERNAME to sudoers: $ADD_TO_SUDOERS"
    if [[ -n "$SSH_KEY" ]]; then
        echo "SSH Key: $SSH_KEY"
    fi
    if [[ -n "$SSH_KEY" ]]; then
        echo "Disable Password Authentication: $DISABLE_PASSWORD_AUTH"
    fi
    echo "Install Wireguard: $INSTALL_WG"
    if [[ "$INSTALL_WG" == "y" ]]; then
        echo "WAN Interface: $WAN_INTERFACE"
        echo "WAN Endpoint: $ENDPOINT"
        echo "Wireguard Port: $WIREGUARD_PORT"
    fi
    echo "Install ZFS: $INSTALL_ZFS"
    echo "Install Virtualization packages: $INSTALL_VIRT"
    echo "Install Docker Engine: $INSTALL_DOCKER"
}

# Ask the user if they want to reboot the system
reboot_system() {
    read -p "Setup completed, please reboot your system, do you want to reboot the system now? (y/n): " REBOOT
    if [[ "$REBOOT" == "y" ]]; then
        reboot
    fi
}


# Order of functions
# Functions order level 2
init() {
    initial_verification
    user_input
}

initial_setup() {
    initial_script_options
    full_upgrade
}

local_modifications() {
    create_user
    change_hostname
    change_timezone
    change_login_page
    secure_ssh
}

install() {
    install_defaultrepo_tools
    centralize_downloads
    install_lazygit
    install_duplicacy
    install_system_services
    if [[ "$INSTALL_ZFS" == "y" ]]; then
        install_zfs
    fi
    if [[ "$INSTALL_VIRT" == "y" ]]; then
        install_virt
    fi
    if [[ "$INSTALL_DOCKER" == "y" ]]; then
        install_docker
        install_lazydocker
    fi
}

setup() {
    setup_user
    setup_zsh
    setup_ufw
    setup_fail2ban
    if [[ "$INSTALL_WG" == "y" ]]; then
        setup_wireguard
        setup_newpeer
    fi
}

end_of_script() {
    cleanup
    recap
    reboot_system
}


# Functions order level 1
no_execution() {
    init
}

execution() {
    initial_setup
    local_modifications
    install
    setup
    end_of_script
}


# Functions order level 0
main() {
    no_execution
    time execution
}


# Run the script
main
