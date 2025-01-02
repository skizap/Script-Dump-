#!/usr/bin/env python3

import os
import subprocess
import sys
from termcolor import colored
import time

def clear_screen():
    """Clears the terminal screen."""
    os.system('clear')

def banner():
    """Displays the ASCII art banner."""
    print(colored("""
    ____  ____  ____  _  _  __   __
   (  _ \(  __)(  _ \/ )( \(  ) /  \\
    ) _ ( ) _)  ) __/) \/ (/ (_/\\  /
   (____/(____)(__)  \\____/\\____/ (__)
    """, 'blue'))

def run_command(command, description=""):
    """Runs a system command with a progress indicator."""
    print(colored(f"{description}...", 'blue'))
    try:
        subprocess.run(command, shell=True, check=True)
        print(colored("Done.", 'green'))
    except subprocess.CalledProcessError as e:
        print(colored(f"Error: {e}", 'red'))

def system_update():
    """Updates the system and enables automatic updates."""
    print(colored("Updating system...", 'blue'))
    run_command("sudo apt update && sudo apt upgrade -y", "Updating system packages")

    print(colored("Checking for unattended-upgrades...", 'blue'))
    try:
        # Check if unattended-upgrades is installed
        result = subprocess.run(["dpkg", "-l", "unattended-upgrades"], stdout=subprocess.PIPE, text=True)
        if "ii  unattended-upgrades" in result.stdout:
            print(colored("unattended-upgrades is already installed.", 'green'))
        else:
            run_command("sudo apt install unattended-upgrades -y", "Installing unattended-upgrades")
    except Exception as e:
        print(colored(f"Error checking unattended-upgrades: {e}", 'red'))

    # Check if configuration for unattended-upgrades is already in place
    config_path = "/etc/apt/apt.conf.d/50unattended-upgrades"
    try:
        if os.path.exists(config_path):
            print(colored("Automatic updates are already configured.", 'green'))
        else:
            with open(config_path, "a") as file:
                file.write("""
                Unattended-Upgrade::Mail "root@localhost";
                Unattended-Upgrade::Automatic-Reboot "true";
                """)
            print(colored("Automatic updates configured.", 'green'))
    except Exception as e:
        print(colored(f"Error configuring automatic updates: {e}", 'red'))

    print(colored("System update process completed.", 'green'))


def system_cleanup():
    """Cleans up unused packages and files."""
    run_command("sudo apt autoremove -y && sudo apt autoclean -y", "Cleaning up the system")

def create_user():
    """Creates a new user with SSH key and password strength checking."""
    username = input(colored("Enter the username for the new user: ", 'blue'))
    ssh_key = input(colored("Enter SSH public key (or leave blank for no SSH key): ", 'blue'))
    run_command(f"sudo adduser {username}", f"Creating user {username}")
    run_command(f"sudo usermod -aG sudo {username}", f"Adding {username} to sudo group")
    if ssh_key:
        os.makedirs(f"/home/{username}/.ssh", exist_ok=True)
        with open(f"/home/{username}/.ssh/authorized_keys", "w") as key_file:
            key_file.write(ssh_key)
        run_command(f"sudo chown -R {username}:{username} /home/{username}/.ssh", "Setting permissions for SSH key")
        print(colored(f"SSH key added for {username}.", 'green'))

def manage_users(): 
    """Provides options to list, delete, or disable users."""
    print(colored("User Management Options:", 'yellow'))
    print("1. List Users")
    print("2. Delete User")
    print("3. Disable User")
    choice = input(colored("Enter your choice: ", 'blue'))

    try:
        with open('/etc/passwd', 'r') as passwd_file:
            # Filter users with UID >= 1000 and exclude "nobody" and "root"
            users = [line.split(':')[0] for line in passwd_file if int(line.split(':')[2]) >= 1000 and line.split(':')[0] not in ['nobody', 'root']]
    except Exception as e:
        print(colored(f"Error reading user list: {e}", 'red'))
        return

    if choice == '1':
        print(colored("Listing users...", 'blue'))
        if users:
            for user in users:
                print(user)
        else:
            print(colored("No users found other than root.", 'yellow'))
        print(colored("Done.", 'green'))
    elif choice == '2':
        if users:
            username = input(colored("Enter username to delete: ", 'blue')).strip()
            if username in users:
                run_command(f"sudo deluser --remove-home {username}", f"Deleting user {username}")
            else:
                print(colored("Invalid username. Operation aborted.", 'yellow'))
        else:
            print(colored("No users available to delete.", 'yellow'))
    elif choice == '3':
        if users:
            username = input(colored("Enter username to disable: ", 'blue')).strip()
            if username in users:
                run_command(f"sudo usermod -L {username}", f"Disabling user {username}")
            else:
                print(colored("Invalid username. Operation aborted.", 'yellow'))
        else:
            print(colored("No users available to disable.", 'yellow'))
    else:
        print(colored("Invalid choice. Returning to menu.", 'red'))


def configure_firewall():
    """Sets up and configures UFW with port and IP management."""
    import subprocess
    from termcolor import colored

    def run_command(command: str, description: str = ""):
        """Helper function to run shell commands with description."""
        print(colored(description, 'blue'))
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        if result.returncode != 0:
            print(colored(f"Error: {result.stderr}", 'red'))
        else:
            print(colored(f"Success: {result.stdout.strip()}", 'green'))

    def fetch_allowed_rules():
        """Fetch and parse UFW allowed rules."""
        ufw_output = subprocess.getoutput("sudo ufw status numbered")
        rules = []
        if "ALLOW" in ufw_output:
            for line in ufw_output.splitlines():
                if "ALLOW" in line:
                    parts = line.split()
                    if parts[0].startswith("[") and parts[0].endswith("]"):
                        rule_number = parts[0].strip("[]")
                        port_protocol = parts[1]
                        port = port_protocol.split('/')[0]
                        rules.append((rule_number, port))
        return rules

    print(colored("Configuring UFW (Uncomplicated Firewall)...", 'blue'))
    run_command("sudo apt install ufw -y", "Installing UFW")

    # Set default firewall rules
    print(colored("Setting default firewall rules...", 'blue'))
    run_command("sudo ufw default deny incoming", "Setting default policy to deny incoming traffic")
    run_command("sudo ufw default allow outgoing", "Setting default policy to allow outgoing traffic")

    while True:
        # Fetch the latest allowed rules
        allowed_rules = fetch_allowed_rules()
        allowed_ports = [rule[1] for rule in allowed_rules]
        print(colored(f"Currently allowed ports: {', '.join(sorted(set(allowed_ports)))}", 'yellow'))

        print(colored("1. Allow new ports", 'blue'))
        print(colored("2. Disable existing ports", 'blue'))
        print(colored("3. Return to Menu", 'blue'))
        action = input(colored("Choose an action (1/2/3): ", 'blue')).strip()

        if action == '3':
            print(colored("Returning to the menu...", 'green'))
            break
        elif action == '1':
            # Prompt for ports to allow
            ports = input(colored("Enter the ports to allow (comma-separated, or leave blank to skip): ", 'blue')).strip()

            if not ports:
                print(colored("No ports provided. Skipping.", 'yellow'))
                continue

            ports_to_allow = ports.split(',')
            valid_ports = []

            for port in ports_to_allow:
                if port in allowed_ports:
                    print(colored(f"Port {port} is already allowed.", 'yellow'))
                elif port.isdigit():
                    valid_ports.append(port)
                else:
                    print(colored(f"Invalid port: {port}. Skipping.", 'red'))

            if valid_ports:
                for port in valid_ports:
                    run_command(f"sudo ufw allow {port}/tcp", f"Allowing port {port}")
                print(colored(f"Allowed ports: {', '.join(valid_ports)}", 'green'))
            else:
                print(colored("No new ports were added.", 'yellow'))
        elif action == '2':
            # Prompt for ports to disable
            ports = input(colored("Enter the ports to disable (comma-separated, or leave blank to skip): ", 'blue')).strip()

            if not ports:
                print(colored("No ports provided. Skipping.", 'yellow'))
                continue

            ports_to_disable = ports.split(',')
            valid_ports = []

            for port in ports_to_disable:
                match_found = False
                # Fetch updated rules dynamically for each port
                allowed_rules = fetch_allowed_rules()
                for rule_number, allowed_port in list(allowed_rules):
                    if port == allowed_port:
                        # Delete both IPv4 and IPv6 rules for the port
                        ipv4_result = subprocess.run(f"sudo ufw --force delete {rule_number}", shell=True, capture_output=True, text=True)
                        ipv6_result = subprocess.run(f"sudo ufw --force delete {rule_number}", shell=True, capture_output=True, text=True)

                        if ipv4_result.returncode == 0 or ipv6_result.returncode == 0:
                            print(colored(f"Disabling port {port}", 'blue'))
                            match_found = True
                            valid_ports.append(port)
                            break
                        else:
                            print(colored(f"Failed to delete port {port}: {ipv4_result.stderr or ipv6_result.stderr}", 'red'))

                if not match_found:
                    print(colored(f"Port {port} is not currently allowed. Skipping.", 'yellow'))

            print(colored(f"Disabled ports: {', '.join(valid_ports)}", 'green') if valid_ports else colored("No ports were disabled.", 'yellow'))
        else:
            print(colored("Invalid choice. Please choose 1, 2, or 3.", 'red'))

    # Enable UFW if not already enabled
    status = subprocess.getoutput("sudo ufw status | grep Status").lower()
    if "inactive" in status:
        run_command("sudo ufw enable", "Enabling UFW")
    else:
        print(colored("UFW is already enabled.", 'green'))

    print(colored("Firewall configuration completed.", 'green'))


def setup_fail2ban(): 
    """Installs and configures Fail2Ban with email alerts."""
    print(colored("Checking if Fail2Ban is already installed...", 'blue'))
    is_installed = os.system("dpkg-query -W -f='${Status}' fail2ban 2>/dev/null | grep -q 'install ok installed'") == 0

    if is_installed:
        print(colored("Fail2Ban is already installed.", 'yellow'))
        is_active = os.system("systemctl is-active --quiet fail2ban") == 0

        if is_active:
            print(colored("Fail2Ban is already active and running.", 'green'))
            return
        else:
            print(colored("Fail2Ban is installed but not active. Restarting service...", 'yellow'))
            run_command("sudo systemctl restart fail2ban", "Restarting Fail2Ban")
            return
    else:
        print(colored("Fail2Ban is not installed. Proceeding with installation...", 'yellow'))

    run_command("sudo apt install fail2ban -y", "Installing Fail2Ban")

    config = """
    [DEFAULT]
    destemail = root@localhost
    sendername = Fail2Ban
    action = %(action_mwl)s

    [sshd]
    enabled = true
    """
    print(colored("Configuring Fail2Ban...", 'blue'))
    try:
        with open("/etc/fail2ban/jail.local", "w") as jail_file:
            jail_file.write(config)
    except Exception as e:
        print(colored(f"Error writing configuration file: {e}", 'red'))
        return

    run_command("sudo systemctl restart fail2ban", "Restarting Fail2Ban")
    print(colored("Fail2Ban setup complete.", 'green'))


def configure_swap(): 
    """Configures a swap file dynamically."""
    print(colored("Checking current swap status...", 'blue'))
    
    # Check if swap is already enabled
    swap_status = subprocess.getoutput("swapon --show")
    if swap_status:
        print(colored("Swap is already enabled. Current swap configuration:", 'yellow'))
        print(swap_status)
        modify = input(colored("Do you want to modify the existing swap file? (yes/no): ", 'blue')).strip().lower()
        if modify != 'yes':
            print(colored("Swap configuration remains unchanged.", 'green'))
            return
        else:
            print(colored("Disabling and removing current swap file...", 'yellow'))
            run_command("sudo swapoff /swapfile", "Disabling current swap")
            run_command("sudo rm -f /swapfile", "Removing current swap file")

    # Get total RAM in MB
    total_ram = int(subprocess.getoutput("free -m | awk '/^Mem:/{print $2}'"))
    
    # Set default swap size or ask user for a custom size
    default_swap_size = max(6 * 1024, total_ram)
    print(colored(f"Default swap size is {default_swap_size}MB (6GB or total RAM, whichever is larger).", 'yellow'))
    swap_size = input(colored(f"Enter swap size in MB (default: {default_swap_size}): ", 'blue')).strip()
    
    try:
        swap_size = int(swap_size) if swap_size else default_swap_size
    except ValueError:
        print(colored("Invalid input. Using default swap size.", 'red'))
        swap_size = default_swap_size

    # Create and enable swap file
    print(colored(f"Configuring a swap file of size {swap_size}MB...", 'blue'))
    run_command(f"sudo fallocate -l {swap_size}M /swapfile", "Creating swap file")
    run_command("sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile", "Activating swap file")

    # Add swap entry to /etc/fstab if not already present
    with open("/etc/fstab", "r") as fstab:
        if "/swapfile none swap sw 0 0" not in fstab.read():
            with open("/etc/fstab", "a") as fstab_write:
                fstab_write.write("/swapfile none swap sw 0 0\n")
            print(colored("Swap file entry added to /etc/fstab.", 'green'))
        else:
            print(colored("Swap file entry already exists in /etc/fstab.", 'yellow'))
    
    print(colored(f"Swap file of size {swap_size}MB configured and activated.", 'green'))


def install_malware_protection():
    """Installs and configures ClamAV for malware protection."""
    run_command("sudo apt install clamav -y", "Installing ClamAV")
    run_command("sudo freshclam", "Updating ClamAV database")
    run_command("sudo systemctl enable clamav-freshclam --now", "Enabling ClamAV updates")
    run_command("(crontab -l 2>/dev/null; echo '0 2 * * * clamscan -r / > /var/log/clamav_scan.log') | crontab -", "Scheduling daily malware scans")

def menu():
    """Displays the interactive main menu."""
    while True:
        clear_screen()
        banner()
        print(colored("Main Menu", 'yellow'))
        print("1. Update System")
        print("2. Clean Up System")
        print("3. Manage Users")
        print("4. Configure Firewall")
        print("5. Install Fail2Ban")
        print("6. Configure Swap File")
        print("7. Install Malware Protection")
        print("8. Exit")
        choice = input(colored("Enter your choice: ", 'blue'))

        if choice == '1':
            system_update()
        elif choice == '2':
            system_cleanup()
        elif choice == '3':
            manage_users()
        elif choice == '4':
            configure_firewall()
        elif choice == '5':
            setup_fail2ban()
        elif choice == '6':
            configure_swap()
        elif choice == '7':
            install_malware_protection()
        elif choice == '8':
            print(colored("Exiting the script. Goodbye!", 'green'))
            break
        else:
            print(colored("Invalid choice. Please try again.", 'red'))
        input(colored("Press Enter to return to the menu...", 'blue'))

if __name__ == "__main__":
    try:
        menu()
    except KeyboardInterrupt:
        print(colored("\nScript interrupted. Exiting.", 'red'))
