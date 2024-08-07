#!/bin/bash

# External links centralized
DOCKER_INSTALL_SCRIPT="https://get.docker.com"
DUPLICACY_RELEASE="https://github.com/gilbertchen/duplicacy/releases/download/v3.2.3/duplicacy_linux_x64_3.2.3"
LAZYDOCKER_INSTALL_SCRIPT="https://raw.githubusercontent.com/upciti/wakemeops/main/assets/install_repository"
LAZYGIT_API="https://api.github.com/repos/jesseduffield/lazygit/releases/latest"
ZSHRC_FILE="https://git.jisoonet.com/el/debsetup/-/raw/main/.zshrc"
WG0_CONF="https://git.jisoonet.com/el/debsetup/-/raw/main/wg0.conf"
NEWPEER_SH="https://git.jisoonet.com/el/debsetup/-/raw/main/newpeer.sh"

# TODO: Add a one click option for full defaults
# TODO: Add an options to segment installation of what I want
# TODO: Better segment initial_setup and group of tools
# TODO: Put all the links variable at the top
# TODO: Output a recap before doing modifications and at the end of script
# TODO: Tell the user how long the isntallation took (or will take if possible), with the time command
# TODO: Centralize all external download at first
# TODO: Create a dotfile repo for debian server
# TODO: Maybe add option to pull usefull docker image, vms, isos, files, etc...
# TODO: Maybe add a default for SSH keys consider public or pricvate rpo of public keys.
# TODO: Add a check for the user to input the public key for the user to verify the user wont be locked out
# TODO: Explicitly say that root password will be disabled
# TODO: Add checks so script is run twice with no problem


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

    # Choose the network interface used for internet connectivity
    DEFAULT_ROUTE=$(ip route get 1.1.1.1)
    WAN_INTERFACE_DEFAULT=$(echo $DEFAULT_ROUTE | grep -oP 'dev \\K\\S+')
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

    # Create a new user or input an existing user
    USERNAME=$(prompt_with_default "Enter the username of the user you wish to create or use" "el")
    echo "You have selected user $USERNAME"

    # Ask for password if user does not exist
    if ! id "$USERNAME" &>/dev/null; then
        read -sp "Enter password for user $USERNAME (input hidden): " USER_PASSWORD
        echo "Password will be set for $USERNAME"
    fi

    # Add new user to sudoers if desired
    ADD_TO_SUDOERS=$(prompt_with_default "Do you want to add $USERNAME to sudoers? (y/n)" "y")
    echo "You have selected $ADD_TO_SUDOERS to sudoers for $USERNAME"

    # Ask for SSH key if desired
    read -p "Enter an SSH Authorized Key for $USERNAME (press Enter to skip): " SSH_KEY
    if [[ -n "$SSH_KEY" ]]; then
        echo "SSH key: $SSH_KEY will be set for $USERNAME"
    fi

    # Ask user if they want to disable password authentication
    if [[ -n "$SSH_KEY" ]]; then
        DISABLE_PASSWORD_AUTH=$(prompt_with_default "Do you want to disable password authentication for SSH? (y/n)" "n")
        echo "You have selected $DISABLE_PASSWORD_AUTH to disable password option for SSH"
    fi
}

# Initial setup
initial_setup() {
    # Begin Setup
    echo "Beginning of Setup..."
    export DEBIAN_FRONTEND=noninteractive

    # Update and upgrade system
    echo "Updating and upgrading your system..."
    apt update
    apt full-upgrade -y

    # Create the user if necessary and set the password
    if ! id "$USERNAME" &>/dev/null; then
        echo "Creating user $USERNAME..."
        useradd -m "$USERNAME"
        echo "$USERNAME:$USER_PASSWORD" | chpasswd
        echo "User $USERNAME created with specified password."
    fi

    # Add user to sudoers if desired
    if [[ "$ADD_TO_SUDOERS" == "y" ]]; then
        usermod -aG sudo "$USERNAME"
        echo "User $USERNAME added to sudoers."
    fi

    # If SSH key is provided, add it to the user's authorized keys
    if [[ -n "$SSH_KEY" ]]; then
        echo "Adding SSH key to $USERNAME's authorized keys..."
        mkdir -p "/home/$USERNAME/.ssh"
        echo "$SSH_KEY" > "/home/$USERNAME/.ssh/authorized_keys"
        chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
        chmod 700 "/home/$USERNAME/.ssh"
        chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
        echo "SSH key added to $USERNAME's authorized keys."
    fi

    # Disable password authentication if desired
    if [[ "$DISABLE_PASSWORD_AUTH" == "y" ]]; then
        echo "Disabling password authentication for SSH..."
        sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/g" /etc/ssh/sshd_config
        systemctl restart ssh
        echo "Password authentication disabled for SSH."
    fi

    # Change the system hostname
    echo "Changing the system hostname..."
    hostnamectl set-hostname "$HOSTNAME"

    echo "Changing time zone to EST..."
    timedatectl set-timezone America/New_York
}

# Install Lazydocker
install_lazydocker() {
    echo "Installing Lazydocker..."
    curl -sSL $LAZYDOCKER_INSTALL_SCRIPT | bash
    apt install lazydocker
}

# Install Lazygit
install_lazygit() {
    LAZYGIT_VERSION=$(curl -s $LAZYGIT_API | grep -Po '"tag_name": "v\\K[^"]*')
    curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf lazygit.tar.gz lazygit
    install lazygit /usr/local/bin
    rm lazygit.tar.gz
    rm lazygit
}

# Install Duplicacy
install_duplicacy() {
    echo "Installing Duplicacy..."
    curl -fsSL $DUPLICACY_RELEASE -o /usr/local/bin/duplicacy
    chmod +x /usr/local/bin/duplicacy
}

# Install packages
install_tools() {
    echo "Installing tools..."
    apt install -y sudo neovim git curl wget mc ffmpeg tmux btop ncdu iftop rclone rsync tree neofetch cpufetch cmatrix fzf exa tldr ripgrep qrencode certbot npm zip unzip htop zsh zsh-syntax-highlighting zsh-autosuggestions
    install_lazydocker
    install_lazygit
    install_duplicacy
}

# Install system services
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

# Install Docker Engine
install_docker() {
    echo "Installing Docker Engine..."
    curl -fsSL $DOCKER_INSTALL_SCRIPT -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
}

# Setup Zsh
setup_zsh() {
    echo "Setting up zsh..."
    curl -o /etc/skel/.zshrc $ZSHRC_FILE
    chmod 644 /etc/skel/.zshrc
    cp /etc/skel/.zshrc /root/
    chsh -s /bin/zsh root
    cp /etc/skel/.zshrc /home/$USERNAME/
    chown $USERNAME:$USERNAME /home/$USERNAME/.zshrc
    chsh -s /bin/zsh $USERNAME
}

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

# Wireguard Setup
setup_wireguard() {
    echo "Setting up Wireguard..."
    curl -o /etc/wireguard/wg0.conf $WG0_CONF
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

# Get newpeer.sh script
setup_newpeer() {
    echo "Downloading and setting up the newpeer.sh script for Wireguard..."
    curl -o /etc/wireguard/newpeer.sh $NEWPEER_SH
    sed -i "s/ENDPOINT/$ENDPOINT/g" /etc/wireguard/newpeer.sh
    sed -i "s/WIREGUARD_PORT/$WIREGUARD_PORT/g" /etc/wireguard/newpeer.sh
}

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

# Secure SSH
secure_ssh() {
    echo "Securing SSH..."
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    sed -i "s/#Port 22/Port $SSH_PORT/g" /etc/ssh/sshd_config
    sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin no/g" /etc/ssh/sshd_config
    systemctl restart ssh
}

# Setup Fail2Ban
setup_fail2ban() {
    echo "Setting up Fail2Ban..."
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.backup
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    sed -i "/^\\[sshd\\]$/,/^\\[/ s/port\\s*=\\s*ssh/port    = $SSH_PORT/g" /etc/fail2ban/jail.local
    systemctl enable fail2ban
    systemctl restart fail2ban
}

# End of script actions
cleanup() {
    echo "End of script actions..."
    apt update
    apt full-upgrade -y
    apt autoremove -y
    rm debsetup.sh
    unset DEBIAN_FRONTEND
    echo "Basic setup completed. Please reboot your server."
}

init() {
    initial_verification
    user_input
}

install() {
    initial_setup
    install_tools
    install_system_services
    install_zfs
    install_virt
    install_docker
}

setup() {
    setup_zsh
    setup_login_page
    setup_wireguard
    setup_newpeer
    setup_ufw
    secure_ssh
    setup_fail2ban
}

cleanup() {
    cleanup
}

main() {
    init
    install
    setup
    cleanup
}

main