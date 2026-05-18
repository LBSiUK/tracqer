from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse

from ..crypto import encrypt, get_key
from ..dependencies import require_auth

router = APIRouter(tags=["auth"])


@router.post("/auth/verify")
async def verify(key: bytes = Depends(require_auth)) -> JSONResponse:
    """
    Clients call this after entering their password to confirm it is correct.
    The request body is an encrypted empty object {}.
    A successful decryption of the response confirms the key is valid.
    """
    return JSONResponse(content=encrypt(key, {"valid": True}))
