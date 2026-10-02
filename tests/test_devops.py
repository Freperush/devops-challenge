import base64
import hashlib
import hmac
import importlib.util
import json
import time
from pathlib import Path

import jwt
from fastapi.testclient import TestClient

from app.main import AUDIENCE, ISSUER, app

API_KEY = "2f5ae96c-b558-4c7b-a590-a501ae1c3f6c"
JWT_SECRET = "test-secret-test-secret-test-sec"
VALID_BODY = {
    "message": "This is a test",
    "to": "Juan Perez",
    "from": "Rita Asturia",
    "timeToLifeSec": 45,
}

client = TestClient(app)
ROOT = Path(__file__).resolve().parents[1]


def _load_generator():
    path = ROOT / "scripts" / "generate_jwt.py"
    spec = importlib.util.spec_from_file_location("generate_jwt", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _token(**overrides) -> str:
    now = int(time.time())
    payload = {
        "jti": "11111111-1111-1111-1111-111111111111",
        "iat": now,
        "nbf": now,
        "exp": now + 900,
        "iss": ISSUER,
        "aud": AUDIENCE,
    }
    payload.update(overrides)
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")


def _post(body=None, api_key=API_KEY, token=None, raw=None, correlation=None):
    headers = {"Content-Type": "application/json"}
    if api_key is not None:
        headers["X-Parse-REST-API-Key"] = api_key
    if token is not None:
        headers["X-JWT-KWY"] = token
    if correlation is not None:
        headers["X-Correlation-ID"] = correlation
    if raw is not None:
        return client.post("/DevOps", content=raw, headers=headers)
    return client.post("/DevOps", json=body, headers=headers)


def test_post_contract():
    response = _post(VALID_BODY, token=_token())
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("application/json")
    assert response.content == b'{"message": "Hello Juan Perez your message will be sent"}'


def test_other_methods_return_error():
    for method in ("GET", "PUT", "PATCH", "DELETE", "OPTIONS"):
        response = client.request(method, "/DevOps")
        assert response.status_code == 405
        assert response.text == "ERROR"
        assert response.headers["allow"] == "POST"
        assert response.headers["content-type"].startswith("text/plain")


def test_head_has_no_body():
    response = client.head("/DevOps")
    assert response.status_code == 405
    assert response.content == b""


def test_get_without_credentials_is_error_not_401():
    response = client.get("/DevOps")
    assert response.status_code == 405
    assert response.text == "ERROR"


def test_invalid_json_without_api_key_is_401():
    response = _post(api_key=None, raw=b"{", token=None)
    assert response.status_code == 401
    assert response.json() == {"error": "unauthorized"}


def test_api_key_missing_wrong_and_valid():
    assert _post(VALID_BODY, api_key=None, token=_token()).status_code == 401
    assert _post(VALID_BODY, api_key="wrong", token=_token()).status_code == 401
    assert _post(VALID_BODY, token=_token()).status_code == 200


def test_jwt_rejections():
    now = int(time.time())
    cases = [
        None,
        "not-a-jwt",
        _token() + "tamper",
        _token(exp=now - 120),
        _token(nbf=now + 120),
        _token(iss="other"),
        _token(aud="other"),
        jwt.encode(
            {"iat": now, "nbf": now, "exp": now + 60, "iss": ISSUER, "aud": AUDIENCE},
            JWT_SECRET,
            algorithm="HS256",
        ),
        jwt.encode(
            {"jti": "x", "iat": now, "nbf": now, "exp": now + 60, "iss": ISSUER, "aud": AUDIENCE},
            JWT_SECRET,
            algorithm="HS384",
        ),
    ]
    for token in cases:
        response = _post(VALID_BODY, token=token)
        assert response.status_code == 401
        assert response.json() == {"error": "unauthorized"}


def test_alg_none_is_rejected():
    header = base64.urlsafe_b64encode(b'{"alg":"none","typ":"JWT"}').rstrip(b"=").decode()
    payload = base64.urlsafe_b64encode(b'{"jti":"x"}').rstrip(b"=").decode()
    response = _post(VALID_BODY, token=f"{header}.{payload}.")
    assert response.status_code == 401


def test_payload_validation():
    for body in (
        {"to": "Juan Perez", "from": "Rita Asturia", "timeToLifeSec": 45},
        {"message": "This is a test", "from": "Rita Asturia", "timeToLifeSec": 45},
        {"message": "This is a test", "to": "Juan Perez", "timeToLifeSec": 45},
        {"message": "This is a test", "to": "Juan Perez", "from": "Rita Asturia"},
        {**VALID_BODY, "timeToLifeSec": "45"},
        {**VALID_BODY, "timeToLifeSec": True},
    ):
        assert _post(body, token=_token()).status_code == 400
    assert _post(raw=b"not-json", token=_token()).status_code == 400
    assert _post(raw=b"[1]", token=_token()).status_code == 400
    extra = {**VALID_BODY, "extra": "ignored"}
    assert _post(extra, token=_token()).status_code == 200
    empty = {**VALID_BODY, "message": "", "to": "Juan Perez"}
    assert _post(empty, token=_token()).status_code == 200


def test_generator_token_is_accepted_and_jti_changes():
    generator = _load_generator()
    first = generator.build_token(JWT_SECRET)
    second = generator.build_token(JWT_SECRET)
    assert _post(VALID_BODY, token=first).status_code == 200
    first_payload = first.split(".")[1] + "=="
    second_payload = second.split(".")[1] + "=="
    assert json.loads(base64.urlsafe_b64decode(first_payload))["jti"] != json.loads(
        base64.urlsafe_b64decode(second_payload)
    )["jti"]


def test_correlation_id_is_propagated_or_generated():
    echoed = _post(VALID_BODY, token=_token(), correlation="corr-1")
    assert echoed.headers["x-correlation-id"] == "corr-1"
    generated = _post(VALID_BODY, token=_token())
    assert generated.headers["x-correlation-id"]


def test_manual_hmac_matches_generator():
    generator = _load_generator()
    token = generator.build_token(JWT_SECRET, now=1_700_000_000, jti="fixed")
    signing_input, signature = token.rsplit(".", 1)
    expected = hmac.new(JWT_SECRET.encode(), signing_input.encode(), hashlib.sha256).digest()
    padded = signature + "=" * (-len(signature) % 4)
    assert base64.urlsafe_b64decode(padded) == expected
