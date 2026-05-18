import hashlib
import hmac
import json
import os
from base64 import b64decode, b64encode

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.primitives.padding import PKCS7

_SALT = b"vinyl-collection-salt"
_ITERATIONS = 100_000
_KEY_LEN = 32  # AES-256

_app_key: bytes | None = None


def init_key(password: str) -> bytes:
    """Derive the AES key from the password and cache it in memory."""
    global _app_key
    _app_key = hashlib.pbkdf2_hmac(
        "sha256", password.encode(), _SALT, _ITERATIONS, _KEY_LEN
    )
    return _app_key


def get_key() -> bytes:
    if _app_key is None:
        raise RuntimeError("Key not initialised — call init_key() at startup")
    return _app_key


def derive_token(key: bytes) -> str:
    """Auth token sent by clients: hex(SHA-256(key))."""
    return hashlib.sha256(key).hexdigest()


def verify_token(token: str) -> bool:
    if _app_key is None:
        return False
    expected = derive_token(_app_key)
    return hmac.compare_digest(expected, token)


def encrypt(key: bytes, data: dict) -> dict:
    """Return an AES-256-CBC encrypted envelope: {"iv": "...", "data": "..."}."""
    iv = os.urandom(16)

    raw = json.dumps(data, default=str).encode()
    padder = PKCS7(128).padder()
    padded = padder.update(raw) + padder.finalize()

    cipher = Cipher(algorithms.AES(key), modes.CBC(iv))
    enc = cipher.encryptor()
    ciphertext = enc.update(padded) + enc.finalize()

    return {
        "iv": b64encode(iv).decode(),
        "data": b64encode(ciphertext).decode(),
    }


def decrypt(key: bytes, envelope: dict) -> dict:
    """Decrypt an envelope produced by encrypt()."""
    iv = b64decode(envelope["iv"])
    ciphertext = b64decode(envelope["data"])

    cipher = Cipher(algorithms.AES(key), modes.CBC(iv))
    dec = cipher.decryptor()
    padded = dec.update(ciphertext) + dec.finalize()

    unpadder = PKCS7(128).unpadder()
    raw = unpadder.update(padded) + unpadder.finalize()

    return json.loads(raw)
