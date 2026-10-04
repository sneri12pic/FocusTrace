"""Disposable staging check. Run on the server: python3 smoke-test.py."""
import json
import os
import secrets
import subprocess
import uuid
from urllib.error import HTTPError
from urllib.request import Request, urlopen

BASE = os.environ.get("FOCUSTRACE_SMOKE_URL", "http://127.0.0.1:18081") + "/api/v1"


def request(method, path, expected, body=None, token=None):
    headers = {"Content-Type": "application/json", "User-Agent": "FocusTrace-Staging-Smoke/1.0"}
    if BASE.startswith("http://127.0.0.1:18081/"):
        # Local tunnel emulation only; Cloudflare supplies these on public requests.
        headers.update({"Host": "staging-sync.stepandemianenko.dev",
                        "CF-Connecting-IP": "203.0.113.10", "X-Forwarded-Proto": "https"})
    if token:
        headers["Authorization"] = "Bearer " + token
    data = None if body is None else json.dumps(body).encode()
    try:
        response = urlopen(Request(BASE + path, data, headers, method=method), timeout=20)
    except HTTPError as error:
        response = error
    with response:
        assert response.status == expected, (method, path, response.status, expected)
        raw = response.read()
        return json.loads(raw) if raw else None


def main():
    request("GET", "/devices", 401)
    credentials = {"email": "staging-" + uuid.uuid4().hex + "@example.com",
                   "password": secrets.token_urlsafe(32)}
    request("POST", "/auth/register", 201, credentials)
    token = request("POST", "/auth/login", 200, credentials)["accessToken"]
    try:
        device = str(uuid.uuid4())
        request("POST", "/devices", 201,
                {"deviceId": device, "displayName": "Staging smoke test", "platform": "android"}, token)
        snapshot = {"deviceId": device, "days": [{"localDate": "2026-10-01",
                    "timezoneId": "Europe/London", "snapshotVersion": 1,
                    "sourceStatus": "reconciled", "apps": [{"appKey": "test.staging",
                    "appName": "Staging test", "durationSeconds": 60, "launchCount": 1}]}]}
        for outcome in ("APPLIED", "DUPLICATE"):
            result = request("PUT", "/sync/usage-days", 200, snapshot, token)
            assert result["results"][0]["outcome"] == outcome
        history = request("GET", "/usage?from=2026-10-01&to=2026-10-02", 200, token=token)
        assert len(history["days"]) == 1
        assert history["days"][0]["deviceId"] == device
        assert history["days"][0]["apps"][0]["durationSeconds"] == 60
        if os.environ.get("FOCUSTRACE_SMOKE_BACKUP_CHECK") == "1":
            subprocess.run(["sh", "maintenance.sh"], check=True)
            subprocess.run(["sh", "verify-backup.sh"], check=True)
    finally:
        request("POST", "/account/delete", 204, {"password": credentials["password"]}, token)
    request("GET", "/devices", 401, token=token)
    print("PASS: authentication, device registration, upload, duplicate retry, history, account deletion")


if __name__ == "__main__":
    main()
