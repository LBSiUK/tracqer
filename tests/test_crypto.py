"""Checks for the encrypted envelope format shared by the API and every client.

The fixed vectors are the same ones the iOS 6 client checks at launch
(ios-6/Tracqer/Tracqer/CryptoParityTest.m), so a change here that breaks them
would also break the clients. Run from the repo root:

    python -m unittest discover tests
"""

import unittest
from base64 import b64decode

from api.crypto import decrypt, derive_token, encrypt, init_key, verify_token

PASSWORD = "test123"
KEY_HEX = "b602babf64d45c5d07e1f5b1a82f6aca4363cabad74b63c4a0a1ce4ee59a4f97"
TOKEN = "dd8bee6ab4376ec7825f20c15048d4edc757fd6a883c3f8e24249f525cd468ee"
FIXED_ENVELOPE = {
    "iv": "AQIDBAUGBwgJCgsMDQ4PEA==",
    "data": "Oz979NkCx/dUEzTkkbMSQBZveI7kkUaK0U5r4VG9z4g=",
}


class CryptoParityTest(unittest.TestCase):
    def setUp(self):
        self.key = init_key(PASSWORD)

    def test_key_derivation_matches_clients(self):
        self.assertEqual(self.key.hex(), KEY_HEX)

    def test_token_matches_clients(self):
        self.assertEqual(derive_token(self.key), TOKEN)
        self.assertTrue(verify_token(TOKEN))
        self.assertFalse(verify_token("0" * 64))

    def test_decrypts_known_envelope(self):
        self.assertEqual(decrypt(self.key, FIXED_ENVELOPE), {"hello": "world", "n": 42})

    def test_round_trip_uses_fresh_iv(self):
        payload = {"title": "Rumours", "year": 1977, "photos": []}
        first = encrypt(self.key, payload)
        second = encrypt(self.key, payload)
        self.assertEqual(len(b64decode(first["iv"])), 16)
        self.assertNotEqual(first["iv"], second["iv"])
        self.assertEqual(decrypt(self.key, first), payload)
        self.assertEqual(decrypt(self.key, second), payload)

    def test_wrong_key_does_not_decrypt(self):
        envelope = encrypt(self.key, {"valid": True})
        other = init_key("not-the-password")
        with self.assertRaises(Exception):
            decrypt(other, envelope)
        init_key(PASSWORD)  # put the module-level key back for other tests


if __name__ == "__main__":
    unittest.main()
