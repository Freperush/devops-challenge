#!/usr/bin/env bash
# Alternative JWT generator. Requires bash and openssl. Prints only the token.
set -euo pipefail

if [[ -z "${JWT_SECRET:-}" ]]; then
  echo "JWT_SECRET is required" >&2
  exit 1
fi

b64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

now=$(date +%s)
exp=$((now + 900))
if command -v uuidgen >/dev/null 2>&1; then
  jti=$(uuidgen | tr '[:upper:]' '[:lower:]')
elif command -v python3 >/dev/null 2>&1; then
  jti=$(python3 -c 'import uuid; print(uuid.uuid4())')
else
  echo "uuidgen or python3 is required" >&2
  exit 1
fi
header=$(printf '%s' '{"alg":"HS256","typ":"JWT"}' | b64url)
payload=$(printf '{"jti":"%s","iat":%s,"nbf":%s,"exp":%s,"iss":"devops-challenge","aud":"devops-api"}' "$jti" "$now" "$now" "$exp" | b64url)
signing="${header}.${payload}"
sig=$(printf '%s' "$signing" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | b64url)
printf '%s\n' "${signing}.${sig}"
