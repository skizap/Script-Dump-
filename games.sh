#!/usr/bin/env bash
###############################################################################
# Mega Hyper Prompt: Comprehensive VPS Management Script
#
# A single, modular Bash script to manage system updates, security, user
# accounts, networking, performance, databases, backups, SSL certs,
# containers, and even game server management.
#
# Script Version: 1.0.3
# Author: skizap (replace with your name or handle)
###############################################################################

###############################################################################
# GLOBAL VARIABLES (Change these as needed)
###############################################################################
SCRIPT_VERSION="1.0.3"
SCRIPT_AUTHOR="John Doe"
MAIN_CONFIG_FILE="/etc/vps_manager.conf"  # Example config file path

# Colors for echo statements (if your terminal supports them)
RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
BLUE=$'\e[34m'
BOLD=$'\e[1m'
RESET=$'\e[0m'

###############################################################################
# FUNCTION TO CENTER TEXT HORIZONTALLY
###############################################################################
# Function to center text horizontally
center_text() {
    local text="$1"
    local term_width
    term_width=$(tput cols)  # Get terminal width

    # Remove ANSI escape sequences for accurate length calculation
    local clean_text
    clean_text=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')

    local text_length=${#clean_text}
    if [ "$text_length" -ge "$term_width" ]; then
        echo -e "$text"
    else
        local padding=$(( (term_width - text_length) / 2 ))
        printf "%*s%s\n" "$padding" "" "$text"
    fi
}

###############################################################################
# FUNCTION TO RUN COMMANDS WITH CENTERED OUTPUT
###############################################################################
# Function to run a command and center its output
run_command_centered() {
    "$@" 2>&1 | while IFS= read -r line; do
        center_text "$line"
    done
}

###############################################################################
# INTRODUCTION & BANNER
###############################################################################

# Display ASCII Art Banner
show_banner() {
  # Define your ASCII art banner
  local banner
  banner=$(cat << "EOF"
     _      _     _            
  __| | ___| |__ (_) __ _ _ __  
 / _` |/ _ \ '_ \| |/ _` | '_ \ 
| (_| |  __/ |_) | | (_| | | | |
 \__,_|\___|_.__/|_|\__,_|_| |_|
EOF
  )

  # Iterate over each line and center it
  while IFS= read -r line; do
    center_text "$line"
  done <<< "$banner"
}

# Welcome Message with Script Version & Author
show_welcome() {
  center_text "${GREEN}Welcome to the VPS Management Script!${RESET}"
  center_text "Version: ${BOLD}${SCRIPT_VERSION}${RESET}"
  center_text "Author: ${BOLD}${SCRIPT_AUTHOR}${RESET}"
  echo
  center_text "This script will help you manage various aspects of your VPS."
  echo
}

###############################################################################
# UTILITY FUNCTIONS
###############################################################################

# Prompt the user and read input safely with trimming and centered prompt
read_input() {
  local prompt_message="$1"
  local user_input
  # Center the prompt message and redirect to stderr
  center_text "${YELLOW}${prompt_message}${RESET}: " >&2
  # Read user input
  read -r user_input
  # Trim leading and trailing whitespace
  user_input=$(echo "$user_input" | xargs)
  # Echo the user input to stdout
  echo "$user_input"
}

# Press any key to continue
pause_function() {
  center_text "\nPress any key to continue..."
  read -n 1 -s
  echo
}

# Check if running as root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: This script must be run as root (or via sudo).${RESET}"
    exit 1
  fi
}

###############################################################################
# MAIN MENU
###############################################################################

# Display Main Menu
main_menu() {
  while true; do
    clear
    show_banner
    show_welcome

    # Define the main menu content
    local menu
    menu=$(cat <<EOF
${BOLD}Main Menu${RESET}
1) System Management
2) Security
3) User Management
4) Networking
5) Performance
6) Database Management
7) Backup Solutions
8) SSL Certificate Management
9) Container Management
10) Game Server Management
X) Exit
EOF
    )

    # Iterate over each line and center it
    while IFS= read -r line; do
      center_text "$line"
    done <<< "$menu"

    choice=$(read_input "Please select an option")

    # Debugging: Print the captured choice
    echo -e "${BLUE}DEBUG: You selected '${choice}'${RESET}"

    case "$choice" in
      1) system_management_menu ;;
      2) security_menu ;;
      3) user_management_menu ;;
      4) networking_menu ;;
      5) performance_menu ;;
      6) database_management_menu ;;
      7) backup_solutions_menu ;;
      8) ssl_management_menu ;;
      9) container_management_menu ;;
      10) game_server_management_menu ;;
      x|X) echo -e "${GREEN}Exiting. Have a great day!${RESET}"; exit 0 ;;
      *) echo -e "${RED}Invalid choice. Please try again.${RESET}"; pause_function ;;
    esac
  done
}

###############################################################################
# 1) SYSTEM MANAGEMENT
###############################################################################
system_management_menu() {
  while true; do
    clear
    echo -e "${BOLD}System Management Menu${RESET}"

    # Define the system management menu content
    local submenu
    submenu=$(cat <<EOF
1) Update & Upgrade System Packages
2) Configure Automatic Updates w/ Email Notifications
3) System Cleanup
B) Back to Main Menu
EOF
    )

    # Iterate over each line and center it
    while IFS= read -r line; do
      center_text "$line"
    done <<< "$submenu"

    choice=$(read_input "Select an option")

    case "$choice" in
      1) update_and_upgrade ;;
      2) configure_automatic_updates ;;
      3) system_cleanup ;;
      b|B) break ;;
      *) echo -e "${RED}Invalid choice. Please try again.${RESET}"; pause_function ;;
    esac
  done
}

# Update and Upgrade System Packages
update_and_upgrade() {
  center_text "${BLUE}Updating and upgrading system packages...${RESET}"
  # For Debian/Ubuntu:
  run_command_centered apt-get update
  run_command_centered apt-get upgrade -y

  center_text "${GREEN}System update and upgrade complete.${RESET}"
  pause_function
}

# Configure Automatic Updates with Email Notifications
configure_automatic_updates() {
  center_text "${BLUE}Configuring automatic updates...${RESET}"
  # Example for Debian/Ubuntu:
  # Install unattended-upgrades and mailutils if not installed
  run_command_centered apt-get install unattended-upgrades mailutils -y

  # Enable unattended-upgrades
  run_command_centered dpkg-reconfigure --priority=low unattended-upgrades

  # Example: edit /etc/apt/apt.conf.d/50unattended-upgrades to set email settings
  # Or set up /etc/cron.daily/apt-compat manually with an email
  local email_address
  email_address=$(read_input "Enter the email address for notifications")

  echo "Unattended-Upgrade::Mail \"${email_address}\";" > /etc/apt/apt.conf.d/99mailnotification
  echo "Unattended-Upgrade::MailOnlyOnError \"true\";" >> /etc/apt/apt.conf.d/99mailnotification

  center_text "${GREEN}Automatic updates configured. Notifications will be sent to ${email_address}.${RESET}"
  pause_function
}

# System Cleanup
system_cleanup() {
  center_text "${BLUE}Cleaning up the system...${RESET}"
  # Remove unnecessary packages
  run_command_centered apt-get autoremove -y
  run_command_centered apt-get autoclean -y

  # Alternatively for CentOS:
  # run_command_centered yum autoremove -y
  # run_command_centered yum clean all

  center_text "${GREEN}System cleanup complete.${RESET}"
  pause_function
}

###############################################################################
# 2) SECURITY
###############################################################################
security_menu() {
  while true; do
    clear
    echo -e "${BOLD}Security Menu${RESET}"

    # Define the security menu content
    local submenu
    submenu=$(cat <<EOF
1) Firewall Configuration (UFW)
2) Fail2Ban Installation and Configuration
3) Malware Protection (ClamAV)
4) Intrusion Detection System (Snort or Suricata)
5) Rootkit and Integrity Checks (rkhunter / chkrootkit)
B) Back to Main Menu
EOF
    )

    # Iterate over each line and center it
    while IFS= read -r line; do
      center_text "$line"
    done <<< "$submenu"

    choice=$(read_input "Select an option")
    case "$choice" in
      1) firewall_configuration ;;
      2) fail2ban_configuration ;;
      3) clamav_installation ;;
      4) ids_installation ;;
      5) rootkit_integrity_checks ;;
      b|B) break ;;
      *) echo -e "${RED}Invalid choice. Please try again.${RESET}"; pause_function ;;
    esac
  done
}

# Firewall Configuration (UFW)
firewall_configuration() {
  center_text "${BLUE}Configuring the firewall (UFW)...${RESET}"
  # Install ufw if not present
  run_command_centered apt-get install ufw -y

  # Set default policies
  run_command_centered ufw default deny incoming
  run_command_centered ufw default allow outgoing

  # Example: Allow SSH
  run_command_centered ufw allow ssh

  # Enable UFW
  run_command_centered ufw --force enable

  center_text "${GREEN}Firewall configured. SSH is allowed by default.${RESET}"
  pause_function
}

# Fail2Ban Installation and Configuration
fail2ban_configuration() {
  center_text "${BLUE}Installing and configuring Fail2Ban...${RESET}"
  run_command_centered apt-get install fail2ban -y

  # Copy default config as local if not already done
  if [ ! -f /etc/fail2ban/jail.local ]; then
    run_command_centered cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
  fi

  # Enable email alerts in jail.local (example)
  # Adjust settings to your needs
  run_command_centered sed -i 's/^destemail =.*/destemail = root@localhost/g' /etc/fail2ban/jail.local
  run_command_centered sed -i 's/^sender =.*/sender = fail2ban@yourdomain.com/g' /etc/fail2ban/jail.local
  run_command_centered sed -i 's/^action =.*/action = %(action_mwl)s/g' /etc/fail2ban/jail.local

  # Restart Fail2Ban to apply changes
  run_command_centered systemctl restart fail2ban

  center_text "${GREEN}Fail2Ban installation and configuration complete.${RESET}"
  pause_function
}

# Malware Protection (ClamAV)
clamav_installation() {
  center_text "${BLUE}Installing ClamAV...${RESET}"
  run_command_centered apt-get install clamav clamav-daemon -y

  # Update the virus definitions
  run_command_centered freshclam

  # Example: schedule a daily scan via cron
  echo "0 2 * * * root /usr/bin/clamscan -r / --exclude-dir=\"^/sys\" --exclude-dir=\"^/proc\" --exclude-dir=\"^/dev\" --log=/var/log/clamav/scan.log" > /etc/cron.d/clamav_scan

  center_text "${GREEN}ClamAV installation complete. A daily scan has been scheduled.${RESET}"
  pause_function
}

# Intrusion Detection System (Snort or Suricata)
ids_installation() {
  center_text "${BLUE}Installing IDS (Snort or Suricata)...${RESET}"
  local ids_choice
  ids_choice=$(read_input "Which IDS would you like to install? (1) Snort, (2) Suricata")

  if [[ $ids_choice -eq 1 ]]; then
    run_command_centered apt-get install snort -y
    # Basic Snort configuration can be added here
    center_text "${GREEN}Snort installed and configured (basic).${RESET}"
  elif [[ $ids_choice -eq 2 ]]; then
    run_command_centered apt-get install suricata -y
    # Basic Suricata configuration can be added here
    center_text "${GREEN}Suricata installed and configured (basic).${RESET}"
  else
    center_text "${RED}Invalid choice. No IDS installed.${RESET}"
  fi
  pause_function
}

# Rootkit and Integrity Checks (rkhunter / chkrootkit)
rootkit_integrity_checks() {
  center_text "${BLUE}Installing rootkit detection tools...${RESET}"
  run_command_centered apt-get install rkhunter chkrootkit -y

  # Update rkhunter DB
  run_command_centered rkhunter --update

  # Run initial scans
  run_command_centered rkhunter --check --sk
  run_command_centered chkrootkit

  center_text "${GREEN}Rootkit scanning tools installed and initial checks completed.${RESET}"
  pause_function
}

###############################################################################
# 3) USER MANAGEMENT
###############################################################################
user_management_menu() {
  while true; do
    clear
    echo -e "${BOLD}User Management Menu${RESET}"

    # Define the user management menu content
    local submenu
    submenu=$(cat <<EOF
1) Create User
2) List Users
3) Delete User
4) Disable User
5) SSH Key Setup
B) Back to Main Menu
EOF
    )

    # Iterate over each line and center it
    while IFS= read -r line; do
      center_text "$line"
    done <<< "$submenu"

    choice=$(read_input "Select an option")
    case "$choice" in
      1) create_user ;;
      2) list_users ;;
      3) delete_user ;;
      4) disable_user ;;
      5) ssh_key_setup ;;
      b|B) break ;;
      *) echo -e "${RED}Invalid choice. Please try again.${RESET}"; pause_function ;;
    esac
  done
}

# Create User
create_user() {
  local username
  username=$(read_input "Enter the new username")

  # Check if user already exists
  if id "$username" &>/dev/null; then
    center_text "${RED}User '$username' already exists.${RESET}"
  else
    run_command_centered adduser "$username"
    center_text "${GREEN}User '$username' created successfully.${RESET}"
  fi
  pause_function
}

# List Users
list_users() {
  center_text "${BLUE}Listing all users on the system...${RESET}"
  run_command_centered cut -d: -f1 /etc/passwd
  pause_function
}

# Delete User
delete_user() {
  local username
  username=$(read_input "Enter the username to delete")

  if id "$username" &>/dev/null; then
    run_command_centered deluser --remove-home "$username"
    center_text "${GREEN}User '$username' has been deleted.${RESET}"
  else
    center_text "${RED}User '$username' does not exist.${RESET}"
  fi
  pause_function
}

# Disable User
disable_user() {
  local username
  username=$(read_input "Enter the username to disable")

  if id "$username" &>/dev/null; then
    run_command_centered usermod -L "$username"
    center_text "${GREEN}User '$username' has been disabled.${RESET}"
  else
    center_text "${RED}User '$username' does not exist.${RESET}"
  fi
  pause_function
}

# SSH Key Setup for User Authentication
ssh_key_setup() {
  local username
  username=$(read_input "Enter the username for SSH key setup")

  if id "$username" &>/dev/null; then
    local ssh_dir="/home/$username/.ssh"
    run_command_centered mkdir -p "$ssh_dir"
    run_command_centered chmod 700 "$ssh_dir"
    run_command_centered chown "$username":"$username" "$ssh_dir"

    center_text "Paste the public key content (e.g., from id_rsa.pub). Press ENTER when done:"
    read -r pubkey

    echo "$pubkey" >> "$ssh_dir/authorized_keys"
    run_command_centered chmod 600 "$ssh_dir/authorized_keys"
    run_command_centered chown "$username":"$username" "$ssh_dir/authorized_keys"

    center_text "${GREEN}SSH key has been set up for user '$username'.${RESET}"
  else
    center_text "${RED}User '$username' does not exist.${RESET}"
  fi
  pause_function
}

###############################################################################
# 4) NETWORKING
###############################################################################
networking_menu() {
  while true; do
    clear
    echo -e "${BOLD}Networking Menu${RESET}"

    # Define the networking menu content
    local submenu
    submenu=$(cat <<EOF
1) Network Configuration (Static IP, DNS)
2) VPN Setup (WireGuard / OpenVPN)
B) Back to Main Menu
EOF
    )

    # Iterate over each line and center it
    while IFS= read -r line; do
      center_text "$line"
    done <<< "$submenu"

    choice=$(read_input "Select an option")
    case "$choice" in
      1) network_configuration ;;
      2) vpn_setup ;;
      b|B) break ;;
      *) echo -e "${RED}Invalid choice. Please try again.${RESET}"; pause_function ;;
    esac
  done
}

# Network Configuration
network_configuration() {
  center_text "${BLUE}Configuring network settings...${RESET}"
  center_text "This section typically involves editing /etc/netplan/*.yaml on Ubuntu/Debian"
  center_text "or using ifcfg scripts on CentOS. Manual edits are recommended."

  center_text "${YELLOW}Please manually edit your netplan or interface configuration files for static IP, DNS, etc.${RESET}"
  pause_function
}

# VPN Setup
vpn_setup() {
  center_text "${BLUE}VPN Setup...${RESET}"
  local vpn_choice
  vpn_choice=$(read_input "Which VPN would you like to install? (1) WireGuard, (2) OpenVPN")

  if [[ $vpn_choice -eq 1 ]]; then
    run_command_centered apt-get install wireguard -y
    # Basic config steps for WireGuard can be added here
    center_text "${GREEN}WireGuard installed (basic). Configure /etc/wireguard/wg0.conf for details.${RESET}"
  elif [[ $vpn_choice -eq 2 ]]; then
    run_command_centered apt-get install openvpn -y
    # Basic config steps for OpenVPN can be added here
    center_text "${GREEN}OpenVPN installed (basic). Further configuration is needed.${RESET}"
  else
    center_text "${RED}Invalid choice. No VPN installed.${RESET}"
  fi
  pause_function
}

###############################################################################
# 5) PERFORMANCE
###############################################################################
performance_menu() {
  while true; do
    clear
    echo -e "${BOLD}Performance Menu${RESET}"

    # Define the performance menu content
    local submenu
    submenu=$(cat <<EOF
1) Monitoring (CPU, Memory, Disk)
2) Performance Tuning (sysctl)
B) Back to Main Menu
EOF
    )

    # Iterate over each line and center it
    while IFS= read -r line; do
      center_text "$line"
    done <<< "$submenu"

    choice=$(read_input "Select an option")
    case "$choice" in
      1) monitoring ;;
      2) performance_tuning ;;
      b|B) break ;;
      *) echo -e "${RED}Invalid choice. Please try again.${RESET}"; pause_function ;;
    esac
  done
}

# Monitoring
monitoring() {
  center_text "${BLUE}System Monitoring...${RESET}"
  center_text "Tools you may use:"
  center_text "- top/htop"
  center_text "- iotop"
  center_text "- free -h"
  center_text "- df -h"
  echo

  # Quick snapshot example:
  center_text "${BOLD}CPU, Memory, and Disk Usage Snapshot:${RESET}"
  center_text "${GREEN}CPU Usage:${RESET}"
  run_command_centered mpstat 2 1 || center_text "Install 'sysstat' for mpstat."

  center_text "\n${GREEN}Memory Usage:${RESET}"
  run_command_centered free -h

  center_text "\n${GREEN}Disk Usage:${RESET}"
  run_command_centered df -h

  pause_function
}

# Performance Tuning
performance_tuning() {
  center_text "${BLUE}Performance Tuning via sysctl...${RESET}"
  # Example sysctl changes
  # Use caution before applying these
  echo "# Increase number of allowed open file descriptors" >> /etc/sysctl.conf
  echo "fs.file-max = 2097152" >> /etc/sysctl.conf

  echo "# Improve IPv4 networking performance" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_fin_timeout = 15" >> /etc/sysctl.conf
  echo "net.ipv4.tcp_window_scaling = 1" >> /etc/sysctl.conf

  run_command_centered sysctl -p

  center_text "${GREEN}Basic sysctl performance tuning applied. Please review /etc/sysctl.conf for custom changes.${RESET}"
  pause_function
}

###############################################################################
# 6) DATABASE MANAGEMENT
###############################################################################
database_management_menu() {
  while true; do
    clear
    echo -e "${BOLD}Database Management Menu${RESET}"

    # Define the database management menu content
    local submenu
    submenu=$(cat <<EOF
1) MySQL Management
2) PostgreSQL Management
B) Back to Main Menu
EOF
    )

    # Iterate over each line and center it
    while IFS= read -r line; do
      center_text "$line"
    done <<< "$submenu"

    choice=$(read_input "Select an option")
    case "$choice" in
      1) mysql_management ;;
      2) postgresql_management ;;
      b|B) break ;;
      *) echo -e "${RED}Invalid choice. Please try again.${RESET}"; pause_function ;;
    esac
  done
}

# MySQL Management
mysql_management() {
  center_text "${BLUE}Managing MySQL...${RESET}"
  run_command_centered apt-get install mysql-server -y

  # Secure installation
  mysql_secure_installation

  center_text "${GREEN}MySQL installed and secured. Use 'mysql' CLI to manage databases/users.${RESET}"
  pause_function
}

# PostgreSQL Management
postgresql_management() {
  center_text "${BLUE}Managing PostgreSQL...${RESET}"
  run_command_centered apt-get install postgresql postgresql-contrib -y

  center_text "${GREEN}PostgreSQL installed. Use 'psql' CLI for management.${RESET}"
  pause_function
}

###############################################################################
# 7) BACKUP SOLUTIONS
###############################################################################
backup_solutions_menu() {
  while true; do
    clear
    echo -e "${BOLD}Backup Solutions Menu${RESET}"

    # Define the backup solutions menu content
    local submenu
    submenu=$(cat <<EOF
1) Data Backup (Rsync with Encryption)
2) Automated Backups (Scheduling, Versioning)
B) Back to Main Menu
EOF
    )

    # Iterate over each line and center it
    while IFS= read -r line; do
      center_text "$line"
    done <<< "$submenu"

    choice=$(read_input "Select an option")
    case "$choice" in
      1) data_backup ;;
      2) automated_backups ;;
      b|B) break ;;
      *) echo -e "${RED}Invalid choice. Please try again.${RESET}"; pause_function ;;
    esac
  done
}

# Data Backup
data_backup() {
  center_text "${BLUE}Performing data backup using rsync...${RESET}"

  local source_dir
  local dest_dir
  source_dir=$(read_input "Enter the source directory to backup")
  dest_dir=$(read_input "Enter the destination directory/location")

  # Simple rsync command
  run_command_centered rsync -avz --delete "$source_dir" "$dest_dir"

  center_text "${GREEN}Backup from '$source_dir' to '$dest_dir' completed.${RESET}"
  pause_function
}

# Automated Backups
automated_backups() {
  center_text "${BLUE}Setting up automated backups with versioning...${RESET}"

  local source_dir
  local dest_dir
  local cron_schedule

  source_dir=$(read_input "Enter the source directory to backup")
  dest_dir=$(read_input "Enter the destination directory/location")
  cron_schedule=$(read_input "Enter the cron schedule (e.g., '0 3 * * *' for 3 AM daily)")

  # Ensure the destination directory exists
  run_command_centered mkdir -p "$dest_dir"

  # Create a cron job with versioned backups using timestamps
  echo "$cron_schedule root rsync -avz --delete \"$source_dir\" \"${dest_dir}/backup_\$(date +\%F_\%H%M%S)\"" >> /etc/crontab

  center_text "${GREEN}Automated backup configured. Versioned backups will be created with timestamps.${RESET}"
  pause_function
}

###############################################################################
# 8) SSL CERTIFICATE MANAGEMENT
###############################################################################
ssl_management_menu() {
  while true; do
    clear
    echo -e "${BOLD}SSL Certificate Management Menu${RESET}"

    # Define the SSL management menu content
    local submenu
    submenu=$(cat <<EOF
1) Let's Encrypt (Certbot)
B) Back to Main Menu
EOF
    )

    # Iterate over each line and center it
    while IFS= read -r line; do
      center_text "$line"
    done <<< "$submenu"

    choice=$(read_input "Select an option")
    case "$choice" in
      1) letsencrypt_certbot ;;
      b|B) break ;;
      *) echo -e "${RED}Invalid choice. Please try again.${RESET}"; pause_function ;;
    esac
  done
}

# Let's Encrypt with Certbot
letsencrypt_certbot() {
  center_text "${BLUE}Obtaining SSL certificates with Let's Encrypt (Certbot)...${RESET}"
  run_command_centered apt-get install certbot -y

  local domain_name
  local email_address

  domain_name=$(read_input "Enter the domain name (e.g., example.com)")
  email_address=$(read_input "Enter your email address for notifications")

  run_command_centered certbot certonly --standalone -d "$domain_name" --agree-tos -m "$email_address" --non-interactive

  center_text "${GREEN}SSL certificate obtained for domain: $domain_name.${RESET}"
  center_text "Automatic renewal is handled by Certbot via systemd timers."
  pause_function
}

###############################################################################
# 9) CONTAINER MANAGEMENT
###############################################################################
container_management_menu() {
  while true; do
    clear
    echo -e "${BOLD}Container Management Menu${RESET}"

    # Define the container management menu content
    local submenu
    submenu=$(cat <<EOF
1) Docker Management
2) Kubernetes Management
B) Back to Main Menu
EOF
    )

    # Iterate over each line and center it
    while IFS= read -r line; do
      center_text "$line"
    done <<< "$submenu"

    choice=$(read_input "Select an option")
    case "$choice" in
      1) docker_management ;;
      2) kubernetes_management ;;
      b|B) break ;;
      *) echo -e "${RED}Invalid choice. Please try again.${RESET}"; pause_function ;;
    esac
  done
}

# Docker Management
docker_management() {
  center_text "${BLUE}Installing and managing Docker...${RESET}"
  # Install Docker
  run_command_centered apt-get install docker.io docker-compose -y

  # Enable and start Docker
  run_command_centered systemctl enable docker
  run_command_centered systemctl start docker

  center_text "${GREEN}Docker installed and started.${RESET}"

  while true; do
    clear
    echo -e "${BOLD}Docker Management${RESET}"

    # Define the Docker management menu content
    local submenu
    submenu=$(cat <<EOF
1) List Containers
2) Start a Container
3) Stop a Container
4) Remove a Container
B) Back
EOF
    )

    # Iterate over each line and center it
    while IFS= read -r line; do
      center_text "$line"
    done <<< "$submenu"

    docker_choice=$(read_input "Select an option")
    case "$docker_choice" in
      1) run_command_centered docker ps -a ;;
      2) 
         local container_image
         container_image=$(read_input "Enter the image name to start (e.g., nginx:latest)")
         run_command_centered docker run -d --name "$(echo "$container_image" | tr ':' '_')" "$container_image"
         ;;
      3) 
         local container_id_stop
         container_id_stop=$(read_input "Enter the container ID/name to stop")
         run_command_centered docker stop "$container_id_stop"
         ;;
      4)
         local container_id_rm
         container_id_rm=$(read_input "Enter the container ID/name to remove")
         run_command_centered docker rm -f "$container_id_rm"
         ;;
      b|B) break ;;
      *) center_text "${RED}Invalid choice. Please try again.${RESET}" ;;
    esac
    pause_function
  done
}

# Kubernetes Management
kubernetes_management() {
  center_text "${BLUE}Kubernetes Management...${RESET}"
  # This is a placeholder for actual K8s installation (e.g., microk8s, k3s, or kubeadm)
  # For demonstration:
  center_text "Installing kubeadm, kubectl, and kubelet (basic) for a single-node cluster."
  center_text "This may take a few minutes..."

  # Minimal example commands (Ubuntu)
  run_command_centered apt-get install -y apt-transport-https ca-certificates curl
  run_command_centered curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
  run_command_centered echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
  run_command_centered apt-get update
  run_command_centered apt-get install -y kubelet kubeadm kubectl
  run_command_centered kubeadm init

  center_text "${GREEN}Kubernetes (basic) installation completed.${RESET}"
  center_text "Use 'kubectl' to manage your cluster. Additional configuration needed."
  pause_function
}

###############################################################################
# 10) GAME SERVER MANAGEMENT
###############################################################################
game_server_management_menu() {
  while true; do
    clear
    echo -e "${BOLD}Game Server Management Menu${RESET}"

    # Define the game server management menu content
    local submenu
    submenu=$(cat <<EOF
1) LinuxGSM Integration
B) Back to Main Menu
EOF
    )

    # Iterate over each line and center it
    while IFS= read -r line; do
      center_text "$line"
    done <<< "$submenu"

    choice=$(read_input "Select an option")
    case "$choice" in
      1) linuxgsm_integration ;;
      b|B) break ;;
      *) echo -e "${RED}Invalid choice. Please try again.${RESET}"; pause_function ;;
    esac
  done
}

# LinuxGSM Integration
linuxgsm_integration() {
  center_text "${BLUE}Setting up LinuxGSM...${RESET}"
  # Example: installing dependencies and setting up a generic game server
  # Make sure you have the dependencies: curl, wget, tar, bzip2, etc.
  run_command_centered apt-get update
  run_command_centered apt-get install wget curl tar bzip2 -y

  # This is a simplified example
  # For real usage, see: https://linuxgsm.com/
  local game_server
  game_server=$(read_input "Enter the game server type (e.g., csgo, rust, etc.)")

  # Create a user for the game server
  run_command_centered useradd -m -s /bin/bash "$game_server"
  run_command_centered su - "$game_server" -c "wget -O linuxgsm.sh https://linuxgsm.sh && chmod +x linuxgsm.sh && bash linuxgsm.sh $game_server"

  center_text "${GREEN}LinuxGSM downloaded. Switch to the '$game_server' user to install and manage the server.${RESET}"
  center_text "Commands: ./$game_server.sh install, ./$game_server.sh start, etc."
  pause_function
}

###############################################################################
# MAIN ENTRY POINT
###############################################################################
main() {
  check_root
  main_menu
}

main
