"""Run the official curl against a local server. HOST defaults to 127.0.0.1:8080."""

import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_jwt import build_token

HOST = os.environ.get("HOST", "127.0.0.1:8080")
API_KEY = os.environ["API_KEY"]
TOKEN = build_token(os.environ["JWT_SECRET"])
BODY = json.dumps(
    {
        "message": "This is a test",
        "to": "Juan Perez",
        "from": "Rita Asturia",
        "timeToLifeSec": 45,
    }
).encode()


def request(method: str) -> None:
    headers = {"Content-Type": "application/json"}
    data = None
    if method == "POST":
        headers["X-Parse-REST-API-Key"] = API_KEY
        headers["X-JWT-KWY"] = TOKEN
        data = BODY
    req = urllib.request.Request(f"http://{HOST}/DevOps", data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req) as response:  # noqa: S310
            print(method, response.status, response.read().decode())
    except urllib.error.HTTPError as exc:
        print(method, exc.code, exc.read().decode())


if __name__ == "__main__":
    request("POST")
    request("GET")
