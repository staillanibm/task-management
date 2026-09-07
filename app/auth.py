"""JWT authentication and scope-based access control.

Tokens are expected to be issued by an external IdP (Keycloak, Auth0, Entra ID,
etc.). Signature, issuer and audience are validated against that IdP's
configuration (JWT_ISSUER / JWT_AUDIENCE / JWT_JWK_URL, set externally per
environment) - this module does not mint or manage tokens itself.

Access control is scope-based, using the standard OAuth2 `scope` claim (a
space-delimited string) or the `scp` claim used by some IdPs (string or list):

- `tasks:read`  grants read-only calls (GET).
- `tasks:full`  grants every call (GET/POST/PUT/DELETE).

Set AUTH_DISABLED=true to turn off all enforcement and reproduce the
previous, unauthenticated behavior.
"""

from __future__ import annotations

from typing import Optional

import jwt
from fastapi import HTTPException, Request
from jwt import PyJWKClient

from app.config import get_settings

SCOPE_READ = "tasks:read"
SCOPE_FULL = "tasks:full"

_jwk_client: Optional[PyJWKClient] = None


def _unauthorized(message: str) -> HTTPException:
    return HTTPException(
        status_code=401,
        detail={"code": "UNAUTHORIZED", "message": message},
        headers={"WWW-Authenticate": "Bearer"},
    )


def _get_jwk_client(jwk_url: str) -> PyJWKClient:
    """Cache the PyJWKClient (and its key cache) across requests."""
    global _jwk_client
    if _jwk_client is None or _jwk_client.uri != jwk_url:
        _jwk_client = PyJWKClient(jwk_url)
    return _jwk_client


def _extract_scopes(payload: dict) -> set[str]:
    raw = payload.get("scope", payload.get("scp"))
    if isinstance(raw, str):
        return set(raw.split())
    if isinstance(raw, (list, tuple)):
        return {str(item) for item in raw}
    return set()


def _decode_token(token: str) -> dict:
    settings = get_settings()
    if not (settings.jwt_issuer and settings.jwt_audience and settings.jwt_jwk_url):
        raise HTTPException(
            status_code=500,
            detail={
                "code": "INTERNAL_ERROR",
                "message": (
                    "JWT auth is enabled but not configured: JWT_ISSUER, "
                    "JWT_AUDIENCE and JWT_JWK_URL must all be set."
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


def require_scope(required_scope: str):
    """FastAPI dependency factory enforcing a minimum scope.

    `tasks:full` always satisfies any required scope, since it grants every
    call including read-only ones.
    """

    def dependency(request: Request) -> None:
        settings = get_settings()
        if settings.auth_disabled:
            return

        auth_header = request.headers.get("authorization", "")
        scheme, _, token = auth_header.partition(" ")
        if scheme.lower() != "bearer" or not token:
            raise _unauthorized("Missing bearer token")

        payload = _decode_token(token)
        scopes = _extract_scopes(payload)
        if required_scope not in scopes and SCOPE_FULL not in scopes:
            raise HTTPException(
                status_code=403,
                detail={
                    "code": "FORBIDDEN",
                    "message": f"Token is missing the required scope '{required_scope}'",
                },
            )

    return dependency
