"""Run on staging: python3 proxy-test.py. Sends only synthetic requests."""
from concurrent.futures import ThreadPoolExecutor
from http.client import HTTPConnection
import json
import uuid


def request(headers=None, body=None, method="GET"):
    connection = HTTPConnection("127.0.0.1", 18081, timeout=20)
    base = {"Content-Type": "application/json", "Host": "staging-sync.stepandemianenko.dev",
            "CF-Connecting-IP": "203.0.113.11", "X-Forwarded-Proto": "https"}
    base.update(headers or {})
    try:
        connection.request(method, "/api/v1/auth/login" if body else "/api/v1/devices",
                           body, base)
        response = connection.getresponse()
        response.read()
        return response.status, response.getheader("Location")
    finally:
        connection.close()


def main():
    assert request({"CF-Connecting-IP": ""})[0] == 400
    assert request({"CF-Connecting-IP": "not-an-ip"})[0] == 400
    assert request({"Host": "stepandemianenko.dev"})[0] == 421
    assert request({"X-Forwarded-Proto": "http"}) == (
        308, "https://staging-sync.stepandemianenko.dev/api/v1/devices")
    assert request(body="x" * (2 * 1024 * 1024 + 1), method="POST")[0] == 413
    # Change the attacker-controlled forwarding header every time. The source
    # remains the Cloudflare visitor address, so the eleventh login is throttled.
    for index in range(11):
        body = json.dumps({"email": uuid.uuid4().hex + "@example.com",
                           "password": "synthetic-wrong-password"})
        status, _ = request({"Content-Type": "application/json",
                             "X-Forwarded-For": "198.51.100." + str(index + 1)}, body, "POST")
        assert status == (401 if index < 10 else 429), (index, status)
    assert request({"CF-Connecting-IP": "203.0.113.12"},
                   json.dumps({"email": uuid.uuid4().hex + "@example.com",
                               "password": "synthetic-wrong-password"}), "POST")[0] == 401
    with ThreadPoolExecutor(max_workers=12) as pool:
        statuses = list(pool.map(lambda _: request({"CF-Connecting-IP": "203.0.113.13"})[0], range(45)))
    assert 429 in statuses, statuses
    assert all(status in (401, 429) for status in statuses), statuses
    print("PASS: missing/invalid visitor IP, hostname isolation, HTTPS redirect, body cap, "
          "spoof-resistant source budgets, separate clients, proxy burst limit")


if __name__ == "__main__":
    main()
