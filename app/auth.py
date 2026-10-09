"""Access control: JWT bearer tokens and HTTP Basic auth, both scope-based.

JWT tokens are expected to be issued by an external IdP (Keycloak, Auth0,
Entra ID, etc.). Signature, issuer and audience are validated against that
IdP's configuration (JWT_ISSUER / JWT_AUDIENCE / JWT_JWK_URL, set externally
per environment) - this module does not mint or manage tokens itself.

Two scopes are recognized, read from the standard OAuth2 `scope` claim (a
space-delimited string) or the `scp` claim used by some IdPs (string or
list):

- `tasks:read`  grants read-only calls (GET).
- `tasks:write` grants write calls (POST/PUT/DELETE).

A client needs both scopes to have full access - neither implies the other.

As an alternative to a JWT, a request can authenticate with HTTP Basic auth,
using credentials configured externally via the BASIC_AUTH_USERNAME and
BASIC_AUTH_PASSWORD environment variables (typically injected from a
Kubernetes Secret). Valid Basic auth credentials grant the admin role, i.e.
both scopes (full access).
"""

from __future__ import annotations

import base64
import secrets
from typing import Optional

import jwt
from fastapi import HTTPException, Request
from jwt import PyJWKClient

from app.config import get_settings

SCOPE_READ = "tasks:read"
SCOPE_WRITE = "tasks:write"

_jwk_client: Optional[PyJWKClient] = None


def _unauthorized(message: str, scheme: str = "Bearer") -> HTTPException:
    return HTTPException(
        status_code=401,
        detail={"code": "UNAUTHORIZED", "message": message},
        headers={"WWW-Authenticate": scheme},
    )


def _get_jwk_client(jwk_url: str) -> PyJWKClient:
    """Cache the PyJWKClient (and its key cache) across requests."""
    global _jwk_client
    if _jwk_client is None or _jwk_client.uri != jwk_url:
        _jwk_client = PyJWKClient(jwk_url)
    return _jwk_client


def _extract_scopes_from_token(payload: dict) -> set[str]:
    raw = payload.get("scope", payload.get("scp"))
    if isinstance(raw, str):
        return set(raw.split())
    if isinstance(raw, (list, tuple)):
        return {str(item) for item in raw}
    return set()


def _extract_roles_from_token(payload: dict) -> set[str]:
    realm_access = payload.get("realm_access")
    roles = realm_access.get("roles") if isinstance(realm_access, dict) else None
    return {str(role) for role in roles} if isinstance(roles, (list, tuple)) else set()


def _decode_token(token: str) -> dict:
    settings = get_settings()
    if not (settings.jwt_issuer and settings.jwt_audience and settings.jwt_jwk_url):
        raise HTTPException(
            status_code=500,
            detail={
                "code": "INTERNAL_ERROR",
                "message": (
                    "JWT auth is not configured: JWT_ISSUER, JWT_AUDIENCE and "
                    "JWT_JWK_URL must all be set."
                ),
            },
        )

    try:
        signing_key = _get_jwk_client(settings.jwt_jwk_url).get_signing_key_from_jwt(token)
        return jwt.decode(
            token,
            signing_key.key,
            algorithms=[alg.strip() for alg in settings.jwt_algorithms.split(",")],
            issuer=settings.jwt_issuer,
            audience=settings.jwt_audience,
            leeway=settings.jwt_leeway_seconds,
        )
    except jwt.PyJWTError as exc:
        raise _unauthorized(f"Invalid token: {exc}")


def _check_basic_auth(encoded_credentials: str) -> set[str]:
    settings = get_settings()
    if not (settings.basic_auth_username and settings.basic_auth_password):
        raise _unauthorized("Basic auth is not configured on this server", scheme="Basic")

    try:
        decoded = base64.b64decode(encoded_credentials).decode("utf-8")
    except (ValueError, UnicodeDecodeError):
        raise _unauthorized("Invalid Basic auth credentials", scheme="Basic")

    username, _, password = decoded.partition(":")
    username_ok = secrets.compare_digest(username, settings.basic_auth_username)
    password_ok = secrets.compare_digest(password, settings.basic_auth_password)
    if not (username_ok and password_ok):
        raise _unauthorized("Invalid Basic auth credentials", scheme="Basic")

    # Basic auth is the admin role: full access, both scopes.
    return {SCOPE_READ, SCOPE_WRITE}


def _resolve_auth(request: Request) -> tuple[set[str], Optional[str], set[str]]:
    """Return the granted scopes, the caller's email (None for Basic auth or a token without `email`)
    and the realm roles of the caller (Basic auth carries the admin role)."""
    auth_header = request.headers.get("authorization", "")
    scheme, _, credentials = auth_header.partition(" ")
    scheme = scheme.lower()

    if scheme == "basic" and credentials:
        return _check_basic_auth(credentials), None, {get_settings().admin_role}

    if scheme == "bearer" and credentials:
        payload = _decode_token(credentials)
        return _extract_scopes_from_token(payload), payload.get("email"), _extract_roles_from_token(payload)

    raise _unauthorized("Missing bearer token or Basic auth credentials")


def require_scope(required_scope: str, admin_only: bool = False):
    """FastAPI dependency factory enforcing a minimum scope.

    Accepts either `Authorization: Basic <credentials>` (admin role, both
    scopes) or `Authorization: Bearer <jwt>` (scopes read from the token).
    With `admin_only`, the caller must also hold the admin realm role (ADMIN_ROLE setting; Basic auth always does).
    The dependency returns the `email` claim of the token (None with Basic auth).
    """

    def dependency(request: Request) -> Optional[str]:
        scopes, email, roles = _resolve_auth(request)
        if required_scope not in scopes:
            raise HTTPException(
                status_code=403,
                detail={
                    "code": "FORBIDDEN",
                    "message": f"Missing the required scope '{required_scope}'",
                },
            )
        if admin_only and get_settings().admin_role not in roles:
            raise HTTPException(
                status_code=403,
                detail={
                    "code": "FORBIDDEN",
                    "message": f"This call requires the '{get_settings().admin_role}' role",
                },
            )
        return email

    return dependency
