import requests
import json
import time
from datetime import datetime

class MetasploitRPC:
    def __init__(self, host='127.0.0.1', port=55553, user='sila', password='sila123'):
        self.url = f"http://{host}:{port}/api/"
        self.user = user
        self.passwd = password
        self.token = None
        self.last_ping = 0

    def login(self):
        payload = {
            "method": "auth.login",
            "params": [self.user, self.passwd],
            "jsonrpc": "2.0",
            "id": 1
        }
        try:
            resp = requests.post(self.url, json=payload, timeout=5)
            if resp.status_code == 200:
                self.token = resp.json().get('result', {}).get('token')
                return self.token
        except Exception as e:
            print(f"RPC Login Error: {e}")
        return None

    def call(self, method, params=[]):
        if not self.token:
            if not self.login():
                return None
        # Ensure token is first param if required
        payload = {
            "method": method,
            "params": [self.token] + params,
            "jsonrpc": "2.0",
            "id": 1
        }
        try:
            resp = requests.post(self.url, json=payload, timeout=10)
            if resp.status_code == 200:
                result = resp.json().get('result')
                # Check if session is dead
                if isinstance(result, dict) and result.get('error'):
                    return None
                return result
        except:
            return None
        return None

    def list_sessions(self):
        return self.call("session.list")

    def execute_cmd(self, sid, cmd):
        return self.call("session.execute", [sid, cmd])

    def download_file(self, sid, remote_path, local_path):
        return self.call("session.download", [sid, remote_path, local_path])
