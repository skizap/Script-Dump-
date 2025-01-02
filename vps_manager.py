#!/usr/bin/env python3

import os
import sys
import subprocess
import pwd
import grp
import re
import logging
import psutil
from datetime import datetime
from typing import Optional, Tuple, List
from pathlib import Path

# ANSI color codes for terminal output
class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    GREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    END = '\033[0m'
    BOLD = '\033[1m'

# Setup logging
logging.basicConfig(
    filename='/var/log/vps_manager.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def run_command(command: str, shell: bool = False) -> Tuple[int, str, str]:
    """
    Execute a shell command and return its exit code, stdout, and stderr
    """
    try:
        if shell:
            process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        else:
            process = subprocess.Popen(command.split(), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        stdout, stderr = process.communicate()
        return process.returncode, stdout.decode(), stderr.decode()
    except Exception as e:
        return 1, '', str(e)

def print_colored(message: str, color: str = Colors.BLUE, bold: bool = False) -> None:
    """Print colored text to terminal"""
    if bold:
        print(f"{Colors.BOLD}{color}{message}{Colors.END}")
    else:
        print(f"{color}{message}{Colors.END}")

def print_banner() -> None:
    """Display the program banner"""
    banner = """
    ██╗   ██╗██████╗ ███████╗    ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗ ███████╗██████╗ 
    ██║   ██║██╔══██╗██╔════╝    ████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝ ██╔════╝██╔══██╗
    ██║   ██║██████╔╝███████╗    ██╔████╔██║███████║██╔██╗ ██║███████║██║  ███╗█████╗  ██████╔╝
    ╚██╗ ██╔╝██╔═══╝ ╚════██║    ██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║██╔══╝  ██╔══██╗
     ╚████╔╝ ██║     ███████║    ██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝███████╗██║  ██║
      ╚═══╝  ╚═╝     ╚══════╝    ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝
    """
    print_colored(banner, Colors.BLUE, bold=True)
    print_colored("VPS Management and Security Tool", Colors.GREEN, bold=True)
    print_colored("=" * 80 + "\n", Colors.BLUE)

class SystemUpdater:
    """Handle system updates and automatic update configuration"""
    
    @staticmethod
    def update_system() -> bool:
        """Update system packages"""
        print_colored("Updating system packages...", Colors.BLUE)
        
        commands = [
            "apt update",
            "apt upgrade -y",
            "apt dist-upgrade -y"
        ]
        
        for cmd in commands:
            code, out, err = run_command(cmd, shell=True)
            if code != 0:
                print_colored(f"Error executing {cmd}: {err}", Colors.FAIL)
                logging.error(f"System update failed: {err}")
                return False
        
        print_colored("System update completed successfully!", Colors.GREEN)
        logging.info("System update completed")
        return True

    @staticmethod
    def configure_automatic_updates() -> bool:
        """Configure unattended-upgrades"""
        print_colored("Configuring automatic updates...", Colors.BLUE)
        
        # Install unattended-upgrades
        code, _, err = run_command("apt install -y unattended-upgrades")
        if code != 0:
            print_colored(f"Error installing unattended-upgrades: {err}", Colors.FAIL)
            return False
            
        # Configure email notifications
        email = input("Enter email address for update notifications: ")
        
        config = f"""
Unattended-Upgrade::Mail "{email}";
Unattended-Upgrade::MailReport "on-change";
Unattended-Upgrade::Automatic-Reboot "true";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
"""
        
        try:
            with open('/etc/apt/apt.conf.d/50unattended-upgrades', 'a') as f:
                f.write(config)
        except Exception as e:
            print_colored(f"Error configuring unattended-upgrades: {e}", Colors.FAIL)
            return False
            
        print_colored("Automatic updates configured successfully!", Colors.GREEN)
        return True

class SystemCleaner:
    """Handle system cleanup operations"""
    
    @staticmethod
    def cleanup_system() -> bool:
        """Remove unused packages and clean up system files"""
        print_colored("Cleaning up system...", Colors.BLUE)
        
        commands = [
            "apt autoremove -y",
            "apt autoclean",
            "apt clean"
        ]
        
        for cmd in commands:
            code, out, err = run_command(cmd, shell=True)
            if code != 0:
                print_colored(f"Error during cleanup: {err}", Colors.FAIL)
                return False
        
        print_colored("System cleanup completed successfully!", Colors.GREEN)
        return True

class UserManager:
    """Handle user management operations"""
    
    @staticmethod
    def create_user(username: str, use_ssh_key: bool = False) -> bool:
        """Create a new user and optionally set up SSH key"""
        try:
            # Create user
            code, _, err = run_command(f"useradd -m -s /bin/bash {username}")
            if code != 0:
                print_colored(f"Error creating user: {err}", Colors.FAIL)
                return False
                
            # Set password
            password = input("Enter password for new user: ")
            process = subprocess.Popen(['passwd', username], stdin=subprocess.PIPE)
            process.communicate(input=f"{password}\n{password}\n".encode())
            
            # Add to sudo group
            if input("Add user to sudo group? (y/n): ").lower() == 'y':
                code, _, err = run_command(f"usermod -aG sudo {username}")
                if code != 0:
                    print_colored(f"Error adding user to sudo group: {err}", Colors.FAIL)
            
            # Set up SSH key
            if use_ssh_key:
                ssh_key = input("Enter public SSH key: ")
                ssh_dir = f"/home/{username}/.ssh"
                os.makedirs(ssh_dir, mode=0o700, exist_ok=True)
                with open(f"{ssh_dir}/authorized_keys", 'w') as f:
                    f.write(ssh_key)
                os.chown(ssh_dir, pwd.getpwnam(username).pw_uid, grp.getgrnam(username).gr_gid)
                os.chmod(f"{ssh_dir}/authorized_keys", 0o600)
            
            print_colored(f"User {username} created successfully!", Colors.GREEN)
            return True
            
        except Exception as e:
            print_colored(f"Error creating user: {e}", Colors.FAIL)
            return False

    @staticmethod
    def list_users() -> List[str]:
        """List all non-system users"""
        users = []
        min_uid = 1000  # Standard minimum UID for regular users
        
        with open('/etc/passwd', 'r') as f:
            for line in f:
                fields = line.strip().split(':')
                if int(fields[2]) >= min_uid and fields[6] != '/usr/sbin/nologin':
                    users.append(fields[0])
        
        return users

    @staticmethod
    def delete_user(username: str, remove_home: bool = True) -> bool:
        """Delete a user and optionally their home directory"""
        cmd = f"userdel {'--remove' if remove_home else ''} {username}"
        code, _, err = run_command(cmd)
        
        if code != 0:
            print_colored(f"Error deleting user: {err}", Colors.FAIL)
            return False
            
        print_colored(f"User {username} deleted successfully!", Colors.GREEN)
        return True

    @staticmethod
    def disable_user(username: str) -> bool:
        """Disable a user account"""
        code, _, err = run_command(f"usermod -L {username}")
        if code != 0:
            print_colored(f"Error disabling user: {err}", Colors.FAIL)
            return False
            
        print_colored(f"User {username} disabled successfully!", Colors.GREEN)
        return True

class FirewallManager:
    """Handle UFW firewall configuration"""
    
    @staticmethod
    def setup_ufw() -> bool:
        """Install and configure UFW"""
        print_colored("Setting up UFW firewall...", Colors.BLUE)
        
        # Install UFW if not present
        code, _, err = run_command("apt install -y ufw")
        if code != 0:
            print_colored(f"Error installing UFW: {err}", Colors.FAIL)
            return False
        
        # Configure default policies
        commands = [
            "ufw default deny incoming",
            "ufw default allow outgoing",
            "ufw allow ssh",  # Always allow SSH
            "ufw --force enable"
        ]
        
        for cmd in commands:
            code, _, err = run_command(cmd)
            if code != 0:
                print_colored(f"Error configuring UFW: {err}", Colors.FAIL)
                return False
        
        print_colored("UFW configured successfully!", Colors.GREEN)
        return True

    @staticmethod
    def manage_port(port: int, protocol: str = "tcp", allow: bool = True) -> bool:
        """Allow or deny a specific port"""
        action = "allow" if allow else "deny"
        cmd = f"ufw {action} {port}/{protocol}"
        
        code, _, err = run_command(cmd)
        if code != 0:
            print_colored(f"Error managing port: {err}", Colors.FAIL)
            return False
            
        print_colored(f"Port {port}/{protocol} {action}ed successfully!", Colors.GREEN)
        return True

class Fail2BanManager:
    """Handle Fail2Ban installation and configuration"""
    
    @staticmethod
    def install_fail2ban() -> bool:
        """Install and configure Fail2Ban"""
        print_colored("Installing Fail2Ban...", Colors.BLUE)
        
        # Install Fail2Ban
        code, _, err = run_command("apt install -y fail2ban")
        if code != 0:
            print_colored(f"Error installing Fail2Ban: {err}", Colors.FAIL)
            return False
        
        # Configure jail.local
        jail_config = """
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
destemail = root@localhost
sender = root@localhost
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
"""
        
        try:
            with open('/etc/fail2ban/jail.local', 'w') as f:
                f.write(jail_config)
        except Exception as e:
            print_colored(f"Error configuring Fail2Ban: {e}", Colors.FAIL)
            return False
        
        # Restart Fail2Ban
        code, _, err = run_command("systemctl restart fail2ban")
        if code != 0:
            print_colored(f"Error restarting Fail2Ban: {err}", Colors.FAIL)
            return False
        
        print_colored("Fail2Ban installed and configured successfully!", Colors.GREEN)
        return True

class SwapManager:
    """Handle swap file management"""
    
    @staticmethod
    def get_recommended_swap_size() -> int:
        """Calculate recommended swap size in GB"""
        total_ram = psutil.virtual_memory().total / (1024 ** 3)  # Convert to GB
        return max(6, int(total_ram))

    @staticmethod
    def create_swap(size_gb: int) -> bool:
        """Create and enable a swap file"""
        swap_file = "/swapfile"
        
        # Remove existing swap if present
        if os.path.exists(swap_file):
            code, _, err = run_command("swapoff -a")
            if code != 0:
                print_colored(f"Error disabling existing swap: {err}", Colors.FAIL)
                return False
        
        # Create new swap file
        commands = [
            f"fallocate -l {size_gb}G {swap_file}",
            f"chmod 600 {swap_file}",
            f"mkswap {swap_file}",
            f"swapon {swap_file}"
        ]
        
        for cmd in commands:
            code, _, err = run_command(cmd)
            if code != 0:
                print_colored(f"Error creating swap: {err}", Colors.FAIL)
                return False
        
        # Add to fstab if not already present
        fstab_entry = f"{swap_file} none swap sw 0 0"
        with open('/etc/fstab', 'r') as f:
            if not any(fstab_entry in line for line in f):
                with open('/etc/fstab', 'a') as f:
                    f.write(f"\n{fstab_entry}\n")
        
        print_colored(f"Swap file created and enabled ({size_gb}GB)!", Colors.GREEN)
        return True

class MalwareScanner:
    """Handle ClamAV installation and configuration"""
    
    @staticmethod
    def install_clamav() -> bool:
        """Install and configure ClamAV"""
        print_colored("Installing ClamAV...", Colors.BLUE)
        
        # Stop existing services if they're running
        services = ["clamav-freshclam", "clamav-daemon"]
        for service in services:
            run_command(f"systemctl stop {service}")
        
        # Install ClamAV and related packages
        packages = ["clamav", "clamav-daemon", "clamav-base"]
        for package in packages:
            code, _, err = run_command(f"apt install -y {package}")
            if code != 0:
                print_colored(f"Error installing {package}: {err}", Colors.FAIL)
                return False

        # Create necessary directories with proper permissions
        directories = [
            "/var/log/clamav",
            "/var/lib/clamav",
            "/etc/clamav"
        ]
        
        for directory in directories:
            try:
                os.makedirs(directory, mode=0o755, exist_ok=True)
            except Exception as e:
                print_colored(f"Error creating directory {directory}: {e}", Colors.FAIL)
                return False

        # Create and configure freshclam.conf
        freshclam_conf = """DatabaseOwner clamav
UpdateLogFile /var/log/clamav/freshclam.log
LogVerbose false
LogSyslog false
LogFacility LOG_LOCAL6
LogFileMaxSize 2M
LogRotate true
LogTime true
Foreground false
Debug false
MaxAttempts 5
DatabaseDirectory /var/lib/clamav
DNSDatabaseInfo current.cvd.clamav.net
ConnectTimeout 30
ReceiveTimeout 30
TestDatabases yes
ScriptedUpdates yes
CompressLocalDatabase no
Bytecode true
NotifyClamd /etc/clamav/clamd.conf
# Check for new database 24 times a day
Checks 24
DatabaseMirror db.local.clamav.net
DatabaseMirror database.clamav.net"""

        # Write freshclam configuration
        try:
            with open('/etc/clamav/freshclam.conf', 'w') as f:
                f.write(freshclam_conf)
        except Exception as e:
            print_colored(f"Error writing freshclam configuration: {e}", Colors.FAIL)
            return False

        # Create log files with proper permissions
        log_files = [
            "/var/log/clamav/freshclam.log",
            "/var/log/clamav/clamav.log"
        ]
        
        for log_file in log_files:
            try:
                with open(log_file, 'w') as f:
                    pass  # Create empty file
                os.chmod(log_file, 0o640)
            except Exception as e:
                print_colored(f"Error creating log file {log_file}: {e}", Colors.FAIL)
                return False

        # Set proper ownership for all ClamAV files
        for directory in directories + ["/var/log/clamav/freshclam.log", "/var/log/clamav/clamav.log"]:
            run_command(f"chown -R clamav:clamav {directory}")

        # Stop freshclam service before updating
        run_command("systemctl stop clamav-freshclam")
        
        # Initial update of virus databases
        print_colored("Updating virus databases (this may take a while)...", Colors.BLUE)
        code, out, err = run_command("freshclam --verbose")
        if code != 0:
            print_colored(f"Error updating virus databases: {err}", Colors.FAIL)
            print_colored("This is not critical - the service will retry later.", Colors.WARNING)

        # Start services
        for service in services:
            run_command(f"systemctl start {service}")
            run_command(f"systemctl enable {service}")

        print_colored("ClamAV installed and configured successfully!", Colors.GREEN)
        return True
        
        # Update virus definitions
        code, _, err = run_command("freshclam")
        if code != 0:
            print_colored(f"Error updating virus definitions: {err}", Colors.FAIL)
            return False
        
        # Configure daily scans
        cron_job = "0 2 * * * clamscan -r / --exclude-dir='^/sys|^/proc|^/dev' -l /var/log/clamav/daily_scan.log\n"
        
        try:
            # Create log directory
            os.makedirs("/var/log/clamav", exist_ok=True)
            
            # Add to root's crontab
            with open('/tmp/clamav_cron', 'w') as f:
                f.write(cron_job)
            
            code, _, err = run_command("crontab /tmp/clamav_cron")
            if code != 0:
                print_colored(f"Error setting up cron job: {err}", Colors.FAIL)
                return False
            
            os.remove('/tmp/clamav_cron')
            
        except Exception as e:
            print_colored(f"Error configuring ClamAV: {e}", Colors.FAIL)
            return False
        
        print_colored("ClamAV installed and configured successfully!", Colors.GREEN)
        return True

    @staticmethod
    def update_clamav() -> bool:
        """Update ClamAV virus definitions"""
        print_colored("Updating ClamAV definitions...", Colors.BLUE)
        
        code, _, err = run_command("freshclam")
        if code != 0:
            print_colored(f"Error updating virus definitions: {err}", Colors.FAIL)
            return False
        
        print_colored("ClamAV definitions updated successfully!", Colors.GREEN)
        return True

def main_menu():
    """Display and handle the main menu"""
    while True:
        os.system('clear')
        print_banner()
        
        print_colored("Main Menu:", Colors.BLUE, bold=True)
        print("""
1. System Update and Configuration
   - Update system
   - Configure automatic updates
2. System Cleanup
   - Remove unused packages
   - Clean package cache
3. User Management
   - Create new user
   - List users
   - Delete user
   - Disable user
4. Firewall Configuration
   - Setup UFW
   - Manage ports
5. Fail2Ban Configuration
   - Install and configure Fail2Ban
6. Swap Management
   - Create/modify swap file
7. Malware Protection
   - Install/update ClamAV
8. Exit
""")
        
        choice = input("Enter your choice (1-8): ")
        
        if choice == "1":
            sub_choice = input("1. Update system\n2. Configure automatic updates\nEnter choice: ")
            if sub_choice == "1":
                SystemUpdater.update_system()
            elif sub_choice == "2":
                SystemUpdater.configure_automatic_updates()
        
        elif choice == "2":
            SystemCleaner.cleanup_system()
        
        elif choice == "3":
            sub_choice = input("""
1. Create new user
2. List users
3. Delete user
4. Disable user
Enter choice: """)
            
            if sub_choice == "1":
                username = input("Enter username: ")
                use_ssh = input("Set up SSH key? (y/n): ").lower() == 'y'
                UserManager.create_user(username, use_ssh)
            elif sub_choice == "2":
                users = UserManager.list_users()
                print_colored("\nNon-system users:", Colors.GREEN)
                for user in users:
                    print(f"- {user}")
            elif sub_choice == "3":
                username = input("Enter username to delete: ")
                remove_home = input("Remove home directory? (y/n): ").lower() == 'y'
                UserManager.delete_user(username, remove_home)
            elif sub_choice == "4":
                username = input("Enter username to disable: ")
                UserManager.disable_user(username)
        
        elif choice == "4":
            sub_choice = input("1. Setup UFW\n2. Manage ports\nEnter choice: ")
            if sub_choice == "1":
                FirewallManager.setup_ufw()
            elif sub_choice == "2":
                port = int(input("Enter port number: "))
                protocol = input("Enter protocol (tcp/udp): ")
                action = input("Allow or deny? (a/d): ").lower()
                FirewallManager.manage_port(port, protocol, action == 'a')
        
        elif choice == "5":
            Fail2BanManager.install_fail2ban()
        
        elif choice == "6":
            size = SwapManager.get_recommended_swap_size()
            custom_size = input(f"Recommended swap size is {size}GB. Use custom size? (y/n): ")
            if custom_size.lower() == 'y':
                size = int(input("Enter swap size in GB: "))
            SwapManager.create_swap(size)
        
        elif choice == "7":
            sub_choice = input("1. Install ClamAV\n2. Update virus definitions\nEnter choice: ")
            if sub_choice == "1":
                MalwareScanner.install_clamav()
            elif sub_choice == "2":
                MalwareScanner.update_clamav()
        
        elif choice == "8":
            print_colored("Goodbye!", Colors.GREEN)
            sys.exit(0)
        
        else:
            print_colored("Invalid choice!", Colors.FAIL)
        
        input("\nPress Enter to continue...")

if __name__ == "__main__":
    # Check if running as root
    if os.geteuid() != 0:
        print_colored("This script must be run as root!", Colors.FAIL)
        sys.exit(1)
    
    try:
        main_menu()
    except KeyboardInterrupt:
        print_colored("\nExiting...", Colors.BLUE)
        sys.exit(0)
    except Exception as e:
        print_colored(f"\nAn error occurred: {e}", Colors.FAIL)
        logging.error(f"Unhandled exception: {e}")
        sys.exit(1)