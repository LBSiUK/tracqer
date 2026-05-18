from fastapi import Header, HTTPException, Request

from .crypto import decrypt, get_key, verify_token


async def require_auth(authorization: str = Header(...)) -> bytes:
    """Validate Bearer token and return the AES key."""
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Bearer token")
    token = authorization.removeprefix("Bearer ")
    if not verify_token(token):
        raise HTTPException(status_code=401, detail="Invalid token")
    return get_key()


async def decrypt_body(request: Request) -> dict:
    """
    Decrypt the AES-CBC encrypted request envelope.
    Auth is checked separately via require_auth — call both as dependencies.
    """
    try:
        envelope = await request.json()
        return decrypt(get_key(), envelope)
    except Exception:
        raise HTTPException(status_code=400, detail="Failed to decrypt request body")
