#!/usr/bin/env python3
# Regenerate the crypto parity test vectors used by Tracqer/CryptoParityTest.m.
# Run from the repo root: python3 ios-6/tools/crypto_test_vector.py

import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", "api"))

from crypto import init_key, derive_token, encrypt  # noqa: E402

PASSWORD = "test123"
FIXED_IV = bytes.fromhex("0102030405060708090a0b0c0d0e0f10")
PAYLOAD = {"hello": "world", "n": 42}

key = init_key(PASSWORD)
token = derive_token(key)

real_urandom = os.urandom
os.urandom = lambda n: FIXED_IV if n == 16 else real_urandom(n)
env = encrypt(key, PAYLOAD)
os.urandom = real_urandom

print(f"password   = {PASSWORD!r}")
print(f"key_hex    = {key.hex()}")
print(f"token      = {token}")
print(f"iv_b64     = {env['iv']}")
print(f"data_b64   = {env['data']}")
print(f"plaintext  = {PAYLOAD}")
