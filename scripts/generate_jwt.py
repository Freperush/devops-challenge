#!/usr/bin/env python3
"""Print one HS256 JWT. Uses only the Python standard library."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import time
import uuid

ISSUER = "devops-challenge"
AUDIENCE = "devops-api"
TTL_SECONDS = 15 * 60


def _b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode("ascii")


def build_token(secret: str, now: int | None = None, jti: str | None = None) -> str:
    issued = int(time.time()) if now is None else now
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "jti": jti or str(uuid.uuid4()),
        "iat": issued,
        "nbf": issued,
        "exp": issued + TTL_SECONDS,
        "iss": ISSUER,
        "aud": AUDIENCE,
    }
    signing_input = ".".join(
        [
            _b64url(json.dumps(header, separators=(",", ":")).encode()),
            _b64url(json.dumps(payload, separators=(",", ":")).encode()),
        ]
    )
    signature = hmac.new(
        secret.encode("utf-8"),
        signing_input.encode("ascii"),
        hashlib.sha256,
    ).digest()
    return f"{signing_input}.{_b64url(signature)}"


def main() -> None:
    secret = os.environ.get("JWT_SECRET", "")
    if not secret:
        raise SystemExit("JWT_SECRET is required")
    print(build_token(secret))


if __name__ == "__main__":
    main()
