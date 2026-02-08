import requests
import socket

def check(url):
    try:
        r = requests.get(url, timeout=2)
        print(f"[OK] Connected to {url} - Status: {r.status_code}")
        return True
    except Exception as e:
        print(f"[FAIL] Could not connect to {url} - Error: {e}")
        return False

print("Checking Server Status...")
local_ok = check("http://127.0.0.1:5000/")
ip_ok = check("http://10.149.250.201:5000/")

if not local_ok and not ip_ok:
    print("CONCLUSION: Server is NOT running.")
elif local_ok and not ip_ok:
    print("CONCLUSION: Server is running on LOCALHOST ONLY. Needs restart to bind to 0.0.0.0.")
elif local_ok and ip_ok:
    print("CONCLUSION: Server is running and reachable on IP. Issue is likely FIREWALL blocking external device.")
