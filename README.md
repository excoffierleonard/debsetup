# Debian Server Setup Script

This Bash script is designed to automate the setup of a new Debian-based server with user-defined configurations. It covers various system configurations, user setups, software installations, and security enhancements tailored for a Debian environment.

## Table of Contents
- [Features](#features)
- [Requirements](#requirements)
- [Usage](#usage)
- [Configuration Parameters](#configuration-parameters)
- [Script Functions](#script-functions)
- [Cleanup and Error Handling](#cleanup-and-error-handling)
- [Contributing](#contributing)
- [License](#license)

## Features
- Initial verification for root access and internet connectivity.
- User prompts to gather configuration details for setup.
- Organizes installations into foreground tools and background processes.
- Installs necessary packages and software (Docker, ZFS, Wireguard, etc.).
- User account setup with optional sudoers access.
- Configures secure SSH access with options to disable password authentication.
- Setup of system services like UFW (firewall) and Fail2Ban.
- Automated timezone adjustment based on user IP.
- Provides a recap of changes made before and after script execution.

## Requirements
- A Debian-based OS (Debian 11, 12, or any compatible derivatives).
- Internet connection to download packages and updates.
- Script must be run with root privileges.

## Usage

### Initial Installation

```sh
wget -O setup.sh https://raw.githubusercontent.com/excoffierleonard/debsetup/main/setup.sh && bash setup.sh
```

### Wireguard New Peer

```sh
sh /etc/wireguard/newpeer.sh NEWPEERNAME 
```

## Configuration Parameters
During execution, the user will be prompted for various configurations including:
- Hostname
- Username and password for the new user
- SSH settings including port and authentication methods
- Selection to install software packages including:
  - Wireguard
  - ZFS
  - Docker Engine
  - Virtualization packages

## Script Functions

### Main Functions
The script's primary functions are:

- **initial_verification**: Validates that the script is run as root and checks for internet connectivity.
- **user_input**: Prompts the user for essential information and configurations.
- **full_upgrade**: Updates existing packages to the latest versions.
- **change_hostname**: Sets the system hostname.
- **setup_user**: Creates a new user account based on the user's input.
- **secure_ssh**: Configures SSH settings, including port changes and authentication methods.
- **install_defaultrepo_tools**: Installs essential software packages for server management.
- **install_wireguard**, **install_docker**, **install_zfs**, **install_virt**: Install the respective software based on user choice.
- **setup_ufw**: Configures the Uncomplicated Firewall for basic security rules.
- **recap_end**: Provides a final summary of actions performed by the script.
- **reboot_system**: Prompts user for reboot at the end of the setup process.

### Additional Utilities
- **centralize_downloads**: Fetches necessary installation scripts and configuration files based on chosen software.
- **setup_timezone**: Adjusts the system's timezone automatically.
- **cleanup**: Cleans up temporary files and unneeded packages after setup completion.

## Cleanup and Error Handling
The script includes various `TODO` comments for future improvements:
- Add checks to prevent running the script multiple times without handling existing configurations.
- Implement more granular error handling and cleanup in case of script failure.
- Ensure temporary files are deleted using trap commands.

The script is designed to terminate on errors during critical stages, ensuring the system remains in a consistent state.

## Contributing
Contributions to improve the script are welcome. Please fork the repository and submit a pull request for consideration. Ensure that code complies with Bash scripting best practices and passes lint checks (e.g., using `shellcheck`).

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 
