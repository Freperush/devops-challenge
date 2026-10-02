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
jti=$(uuidgen | tr '[:upper:]' '[:lower:]')
header=$(printf '%s' '{"alg":"HS256","typ":"JWT"}' | b64url)
payload=$(printf '{"jti":"%s","iat":%s,"nbf":%s,"exp":%s,"iss":"devops-challenge","aud":"devops-api"}' "$jti" "$now" "$now" "$exp" | b64url)
signing="${header}.${payload}"
sig=$(printf '%s' "$signing" | openssl dgst -sha256 -hmac "$JWT_SECRET" -binary | b64url)
printf '%s\n' "${signing}.${sig}"
