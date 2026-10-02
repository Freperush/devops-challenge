import hmac
import json
import os
import time
import uuid
from json import JSONDecodeError

import jwt
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, Response
from jwt.exceptions import PyJWTError
from pydantic import BaseModel, ConfigDict, Field, ValidationError

ISSUER = "devops-challenge"
AUDIENCE = "devops-api"
LEEWAY_SECONDS = 30
SUCCESS = "application/json"

app = FastAPI(docs_url=None, redoc_url=None, openapi_url=None, redirect_slashes=False)


class Payload(BaseModel):
    model_config = ConfigDict(extra="ignore", populate_by_name=True)

    message: str
    to: str
    from_: str = Field(alias="from")
    time_to_life_sec: int = Field(alias="timeToLifeSec", strict=True)


def _unauthorized() -> JSONResponse:
    return JSONResponse(status_code=401, content={"error": "unauthorized"})


def _invalid() -> JSONResponse:
    return JSONResponse(status_code=400, content={"error": "invalid request"})


def _method_not_allowed(method: str) -> Response:
    if method == "HEAD":
        return Response(status_code=405, headers={"Allow": "POST"})
    return Response(
        content="ERROR",
        status_code=405,
        media_type="text/plain",
        headers={"Allow": "POST"},
    )


def _api_key_ok(presented: str | None) -> bool:
    expected = os.environ.get("API_KEY", "")
    if not expected or presented is None:
        return False
    return hmac.compare_digest(presented, expected)


def _jwt_ok(token: str | None) -> bool:
    secret = os.environ.get("JWT_SECRET", "")
    if not secret or not token:
        return False
    try:
        claims = jwt.decode(
            token,
            secret,
            algorithms=["HS256"],
            audience=AUDIENCE,
            issuer=ISSUER,
            leeway=LEEWAY_SECONDS,
            options={"require": ["exp", "iat", "nbf", "iss", "aud", "jti"]},
        )
    except PyJWTError:
        return False
    return bool(claims.get("jti"))


@app.api_route(
    "/DevOps",
    methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"],
)
async def devops(request: Request) -> Response:
    started = time.perf_counter()
    correlation_id = request.headers.get("X-Correlation-ID") or str(uuid.uuid4())
    status = 500
    try:
        if request.method != "POST":
            status = 405
            response: Response = _method_not_allowed(request.method)
        elif not _api_key_ok(request.headers.get("X-Parse-REST-API-Key")):
            status = 401
            response = _unauthorized()
        elif not _jwt_ok(request.headers.get("X-JWT-KWY")):
            status = 401
            response = _unauthorized()
        else:
            response = await _accepted_payload(request)
            status = response.status_code
        response.headers["X-Correlation-ID"] = correlation_id
        return response
    finally:
        duration_ms = int((time.perf_counter() - started) * 1000)
        print(
            json.dumps(
                {
                    "method": request.method,
                    "path": request.url.path,
                    "status": status,
                    "duration_ms": duration_ms,
                    "correlation_id": correlation_id,
                }
            ),
            flush=True,
        )


async def _accepted_payload(request: Request) -> Response:
    try:
        data = json.loads(await request.body() or b"")
    except JSONDecodeError:
        return _invalid()
    if not isinstance(data, dict):
        return _invalid()
    try:
        payload = Payload.model_validate(data)
    except ValidationError:
        return _invalid()
    body = json.dumps(
        {"message": f"Hello {payload.to} your message will be sent"},
        separators=(", ", ": "),
    )
    return Response(content=body, status_code=200, media_type="application/json")
