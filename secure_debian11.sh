#!/usr/bin/env bash
#
# secure_debian11.sh
#
# A Bash script to secure a fresh Debian 11 installation on a VPS.
# Features:
# - Enhanced terminal visuals with colors and ASCII art.
# - Robust error handling with detailed error logs.
# - Detects previous runs and skips unnecessary steps.
# - Interactive GUI for firewall configuration with multiple selection options.
#
# Usage:
#   chmod +x secure_debian11.sh
#   ./secure_debian11.sh
#
# Make sure you run this script as root or with sudo privileges!
#

# Exit on any error and treat unset variables as errors
set -euo pipefail
trap 'error_handler' ERR

# Function to handle errors and log them
error_handler() {
  echo -e "\e[31m[ERROR] An error occurred in the script.\e[0m" | tee -a /root/secure_debian11_error.log
  echo "Check /root/secure_debian11_error.log for details." | tee -a /root/secure_debian11_error.log
  exit 1
}

# Function to check if a command is already run
already_run() {
  grep -qxF "$1" /var/log/secure_debian11_run.log 2>/dev/null
}

# Log completed steps
log_step() {
  echo "$1" >> /var/log/secure_debian11_run.log
}

# Colors and ASCII art
GREEN="\e[32m"
BLUE="\e[34m"
CYAN="\e[36m"
RED="\e[31m"
RESET="\e[0m"
ASCII_ART="\e[32m
 _______  _______  _______  _______  _______  ______   _______  __    _
|       ||       ||       ||       ||       ||      | |       ||  |  | |
|    ___||   _   ||   _   ||   _   ||   _   ||  _    ||   _   ||   |_| |
|   | __ |  | |  ||  | |  ||  | |  ||  | |  || | |   ||  | |  ||       |
|   ||  ||  |_|  ||  |_|  ||  |_|  ||  |_|  || |_|   ||  |_|  ||  _    |
|   |_| ||       ||       ||       ||       ||       ||       || | |   |
|_______||_______||_______||_______||_______||______| |_______||_|  |__|
\e[0m"

# Fancy loading animation
loading_animation() {
  for i in {1..3}; do
    echo -ne "\r${CYAN}Processing${RESET}"; sleep 0.2; echo -ne "\r${CYAN}Processing.${RESET}"; sleep 0.2
    echo -ne "\r${CYAN}Processing..${RESET}"; sleep 0.2; echo -ne "\r${CYAN}Processing...${RESET}"; sleep 0.2
  done
  echo -ne "\r${GREEN}Done!${RESET}\n"
}

# Welcome Message
clear
echo -e "$ASCII_ART"
echo -e "${BLUE}Welcome to the Secure Debian 11 Hardening Script!${RESET}\n"

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Please run this script as root (sudo su).${RESET}"
  exit 1
fi

# Check for previous runs
if already_run "secure_debian11.sh"; then
  echo -e "${BLUE}The script has already been run on this system. Skipping reconfiguration steps.${RESET}"
else
  echo "secure_debian11.sh" > /var/log/secure_debian11_run.log
fi

#############################
#  STEP 1: System Updates   #
#############################

echo -e "${CYAN}==> [1/7] Updating the system and enabling auto-updates...${RESET}"
loading_animation

apt update -y
apt upgrade -y
apt dist-upgrade -y
apt install -y unattended-upgrades apt-listchanges

cat <<EOF >/etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Autoremove "7";
EOF

unattended-upgrades --dry-run --debug
log_step "System updates and auto-updates configured."

#############################
# STEP 2: Create New Sudoer #
#############################

echo -e "${CYAN}==> [2/7] Creating a new user with limited privileges...${RESET}"
loading_animation

NEW_USER="gamemaster"
read -s -p "Enter a strong password for the new user: " NEW_USER_PASS
echo

if ! id -u "$NEW_USER" >/dev/null 2>&1; then
  adduser --quiet --disabled-password --gecos "" "$NEW_USER"
  echo "${NEW_USER}:${NEW_USER_PASS}" | chpasswd
  echo "User: $NEW_USER\nPassword: $NEW_USER_PASS" > /root/${NEW_USER}_credentials.txt
  chmod 600 /root/${NEW_USER}_credentials.txt
  echo "Credentials saved to /root/${NEW_USER}_credentials.txt"
  log_step "New user $NEW_USER created."
else
  echo -e "${BLUE}User $NEW_USER already exists. Skipping creation.${RESET}"
fi

usermod -aG sudo "$NEW_USER"

#############################
# STEP 3: Configure Firewall#
#############################

echo -e "${CYAN}==> [3/7] Installing and configuring UFW...${RESET}"
loading_animation

apt install -y ufw

# Terminal GUI for port selection
echo "${CYAN}What is the purpose of this server?${RESET}"
echo "1) General-purpose (22, 80, 443)"
echo "2) Web server (80, 443)"
echo "3) Game server (custom ports)"
echo "4) Custom configuration"
read -p "Enter your choice [1-4]: " PURPOSE

case "$PURPOSE" in
  1)
    PORTS=(22 80 443)
    ;;
  2)
    PORTS=(80 443)
    ;;
  3)
    read -p "Enter game server ports (comma-separated, e.g., 25565,7777): " GAME_PORTS
    IFS=',' read -ra PORTS <<< "$GAME_PORTS"
    ;;
  4)
    read -p "Enter custom ports (comma-separated): " CUSTOM_PORTS
    IFS=',' read -ra PORTS <<< "$CUSTOM_PORTS"
    ;;
  *)
    echo -e "${RED}Invalid choice. Defaulting to general-purpose.${RESET}"
    PORTS=(22 80 443)
    ;;
esac

ufw default deny incoming
ufw default allow outgoing
for PORT in "${PORTS[@]}"; do
  ufw allow ${PORT}/tcp
done

ufw --force enable
ufw status verbose
log_step "Firewall configured with ports: ${PORTS[*]}"

#############################
# STEP 4: Install Fail2Ban  #
#############################

echo -e "${CYAN}==> [4/7] Installing and configuring Fail2Ban...${RESET}"
loading_animation

apt install -y fail2ban

cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sed -i 's/^bantime  = 10m/bantime  = 1h/' /etc/fail2ban/jail.local
sed -i 's/^maxretry = 5/maxretry = 3/' /etc/fail2ban/jail.local

systemctl enable fail2ban
systemctl restart fail2ban
log_step "Fail2Ban installed and configured."

#############################
#   STEP 5: Enable 6G Swap  #
#############################

echo -e "${CYAN}==> [5/7] Enabling a 6GB swap file...${RESET}"
loading_animation

if [ -f /swapfile ]; then
  echo -e "${BLUE}Swapfile /swapfile already exists. Skipping creation.${RESET}"
else
  if ! fallocate -l 6G /swapfile; then
    echo "fallocate failed; using dd instead."
    dd if=/dev/zero of=/swapfile bs=1G count=6
  fi

  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile

  cp /etc/fstab /etc/fstab.bak.$(date +%F_%T)
  echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
  log_step "6GB swap file created and enabled."
fi

sysctl vm.swappiness=10
if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
  echo "vm.swappiness=10" >> /etc/sysctl.conf
fi

#############################
#STEP 6: Malware Scanner    #
#############################

echo -e "${CYAN}==> [6/7] Installing and configuring ClamAV...${RESET}"
loading_animation

apt install -y clamav clamav-daemon

if ! id -u clamav &>/dev/null; then
  groupadd --system clamav
  useradd --system --shell /bin/false --no-create-home -g clamav -c "Clam AntiVirus" clamav
fi

systemctl stop clamav-freshclam || true
systemctl stop clamav-daemon || true

mkdir -p /var/log/clamav
mkdir -p /var/lib/clamav
chown -R clamav:clamav /var/log/clamav /var/lib/clamav
chmod 755 /var/log/clamav /var/lib/clamav

freshclam

systemctl enable clamav-freshclam
systemctl start clamav-freshclam

systemctl enable clamav-daemon
systemctl start clamav-daemon
log_step "ClamAV installed and configured."

#############################
# STEP 7: Regular Maintenance
#############################

echo -e "${CYAN}==> [7/7] Final notes on regular maintenance...${RESET}"

cat <<EOF
${GREEN}========================================${RESET}
System hardening steps are completed!
New user '${NEW_USER}' has been created.
Firewall configured with ports: ${PORTS[*]}.
Credentials saved in /root/${NEW_USER}_credentials.txt.
6GB swap enabled.
ClamAV installed.
${GREEN}========================================${RESET}
EOF
log_step "System hardening completed."

