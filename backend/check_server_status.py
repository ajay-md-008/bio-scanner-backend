import requests
import socket

def check(url):
    try:
        r = requests.get(url, timeout=2)
        print(f"[OK] Connected to {url} - Status: {r.status_code}")
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
print("Checking Cloud Server Status...")
cloud_ok = check("https://bio-scanner-api.onrender.com/health")

if cloud_ok:
    print("CONCLUSION: Cloud Server is ONLINE.")
else:
    print("CONCLUSION: Cloud Server is OFFLINE or waking up. Please wait and try again.")
