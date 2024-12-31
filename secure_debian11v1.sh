#!/usr/bin/env bash
#
# secure_debian11.sh
#
# A Bash script to secure a fresh Debian 11 installation on a VPS.
#
# Steps:
#   1. Update the system and enable auto-updates
#   2. Create a new user with limited privileges
#   3. Configure a firewall (UFW) to allow ports 22, 80, 443
#   4. Install and configure Fail2Ban
#   5. Enable a 6GB swap
#   6. Install and configure a malware scanner (ClamAV as an example)
#   7. Regular maintenance tips
#
# Usage:
#   chmod +x secure_debian11.sh
#   ./secure_debian11.sh
#
# Make sure you run this script as root or with sudo privileges!
#

# Exit on any error and treat unset variables as errors
set -euo pipefail

#############################
#       STEP 0: Checks      #
#############################

# Ensure script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root (sudo su)."
  exit 1
fi

#############################
#  STEP 1: System Updates   #
#############################

echo "==> [1/7] Updating the system and enabling auto-updates..."

# Update apt package index
apt update -y

# Upgrade all packages
apt upgrade -y

# (Optional) Full distribution upgrade
apt dist-upgrade -y

# Install unattended-upgrades to enable automatic security updates
apt install -y unattended-upgrades apt-listchanges

# Configure unattended-upgrades
cat <<EOF >/etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
# Optional: remove unused deps automatically
# APT::Periodic::AutocleanInterval "7";
# APT::Periodic::Autoremove "7";
EOF

unattended-upgrades --dry-run --debug

#############################
# STEP 2: Create New Sudoer #
#############################

echo "==> [2/7] Creating a new user with limited privileges..."

# Adjust the following variables according to your preference
NEW_USER="USERNAMEHERE"  # Replace with your desired username
NEW_USER_PASS="PASSWORDHERE"  # Replace with a strong password

# Create the new user if it doesn't exist
if ! id -u "$NEW_USER" >/dev/null 2>&1; then
  adduser --quiet --disabled-password --gecos "" "$NEW_USER"
  echo "${NEW_USER}:${NEW_USER_PASS}" | chpasswd
fi

# Add the user to the sudo group
usermod -aG sudo "$NEW_USER"

# (Optional) Disable root SSH login for extra security
# sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
# systemctl restart ssh

#############################
# STEP 3: Configure Firewall#
#############################

echo "==> [3/7] Installing and configuring UFW..."

apt install -y ufw

# Default policies
ufw default deny incoming
ufw default allow outgoing

# Open SSH port 22
ufw allow 22/tcp

# Open HTTP port 80 and HTTPS port 443
ufw allow 80/tcp
ufw allow 443/tcp

# Enable UFW
ufw --force enable
ufw status verbose

#############################
# STEP 4: Install Fail2Ban  #
#############################

echo "==> [4/7] Installing and configuring Fail2Ban..."

apt install -y fail2ban

# Basic Fail2Ban configuration
# Copy the default config and create a local override
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# Typical defaults: ban for 1 hour, max 3 retries
sed -i 's/^bantime  = 10m/bantime  = 1h/' /etc/fail2ban/jail.local
sed -i 's/^maxretry = 5/maxretry = 3/' /etc/fail2ban/jail.local

# Restart and enable Fail2Ban
systemctl enable fail2ban
systemctl restart fail2ban

#############################
#   STEP 5: Enable 6G Swap  #
#############################

echo "==> [5/7] Enabling a 6GB swap file..."

# Check if a swapfile already exists
if [ -f /swapfile ]; then
  echo "Swapfile /swapfile already exists, skipping creation..."
else
  # Create a 6GB swapfile
  fallocate -l 6G /swapfile || dd if=/dev/zero of=/swapfile bs=1G count=6

  # Secure the swapfile by restricting permissions
  chmod 600 /swapfile

  # Make it a swap area
  mkswap /swapfile

  # Enable the swapfile
  swapon /swapfile

  # Backup fstab before editing
  cp /etc/fstab /etc/fstab.bak.$(date +%F_%T)

  # Make the swapfile permanent
  echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
fi

# Optionally adjust swappiness (default is 60)
sysctl vm.swappiness=10
if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
  echo "vm.swappiness=10" >> /etc/sysctl.conf
fi

#############################
#STEP 6: Malware Scanner    #
#############################

echo "==> [6/7] Installing and configuring ClamAV (example malware scanner)..."

# Install ClamAV
apt install -y clamav clamav-daemon

# Ensure ClamAV user and group exist (sometimes the package might fail to create them)
if ! id -u clamav &>/dev/null; then
  echo "Creating clamav system user and group..."
  groupadd --system clamav
  useradd --system --shell /bin/false --no-create-home -g clamav -c "Clam AntiVirus" clamav
fi

# Stop services to prevent lock conflicts
systemctl stop clamav-freshclam || true
systemctl stop clamav-daemon || true

# Make sure log and lib directories exist and have correct permissions
mkdir -p /var/log/clamav
mkdir -p /var/lib/clamav
chown -R clamav:clamav /var/log/clamav /var/lib/clamav
chmod 755 /var/log/clamav /var/lib/clamav

# Update ClamAV virus definitions (as root, but the database/log belongs to clamav user)
freshclam

# Enable and start ClamAV services
systemctl enable clamav-freshclam
systemctl start clamav-freshclam

systemctl enable clamav-daemon
systemctl start clamav-daemon

#############################
# STEP 7: Regular Maintenance
#############################

echo "==> [7/7] Final notes on regular maintenance..."

# 1. Ensure logs are rotated:
#    - Debian uses logrotate by default. Check /etc/logrotate.conf and /etc/logrotate.d/*.
# 2. Regularly check for updates:
#    - Even with unattended-upgrades, occasionally run apt update && apt upgrade -y manually.
# 3. Monitor logs for suspicious activity:
#    - /var/log/auth.log (SSH and sudo logs)
#    - /var/log/syslog
# 4. Perform routine scans with ClamAV (or your preferred malware scanner).
# 5. Consider implementing intrusion detection (e.g., AIDE or OSSEC).

echo "========================================"
echo " System hardening steps are completed! "
echo " New user '${NEW_USER}' has been created. "
echo " Firewall, Fail2Ban, and ClamAV installed. "
echo " 6GB swap enabled. "
echo "========================================"
