"""Access control: JWT bearer tokens and an API key, both scope-based.

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

As an alternative to a JWT, a request can authenticate with a static API key
(`X-API-Key` header), configured externally via the API_KEY environment
variable (typically injected from a Kubernetes Secret). A valid API key
grants both scopes (full access).
"""

from __future__ import annotations

import secrets
from typing import Optional

import jwt
from fastapi import HTTPException, Request
from jwt import PyJWKClient

from app.config import get_settings

SCOPE_READ = "tasks:read"
SCOPE_WRITE = "tasks:write"

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


def _extract_scopes_from_token(payload: dict) -> set[str]:
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


def _resolve_scopes(request: Request) -> set[str]:
    api_key = request.headers.get("x-api-key")
    if api_key is not None:
        settings = get_settings()
        if not settings.api_key:
            raise _unauthorized("API key authentication is not configured on this server")
        if not secrets.compare_digest(api_key, settings.api_key):
            raise _unauthorized("Invalid API key")
        return {SCOPE_READ, SCOPE_WRITE}

    auth_header = request.headers.get("authorization", "")
    scheme, _, token = auth_header.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise _unauthorized("Missing bearer token or API key")

    payload = _decode_token(token)
    return _extract_scopes_from_token(payload)


def require_scope(required_scope: str):
    """FastAPI dependency factory enforcing a minimum scope.

    Accepts either a `X-API-Key` header or an `Authorization: Bearer <jwt>`
    header. A valid API key carries both scopes.
    """

    def dependency(request: Request) -> None:
        scopes = _resolve_scopes(request)
        if required_scope not in scopes:
            raise HTTPException(
                status_code=403,
                detail={
                    "code": "FORBIDDEN",
                    "message": f"Missing the required scope '{required_scope}'",
                },
            )

    return dependency
