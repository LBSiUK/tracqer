export interface Envelope {
  iv: string;
  data: string;
}

const SALT = new TextEncoder().encode("vinyl-collection-salt");
const PBKDF2_ITERATIONS = 100_000;
const KEY_LENGTH = 32; // bytes (256-bit)

export async function deriveKey(password: string): Promise<CryptoKey> {
  const passwordBytes = new TextEncoder().encode(password);

  const baseKey = await crypto.subtle.importKey(
    "raw",
    passwordBytes,
    { name: "PBKDF2" },
    false,
    ["deriveKey"]
  );

  const derivedKey = await crypto.subtle.deriveKey(
    {
      name: "PBKDF2",
      salt: SALT,
      iterations: PBKDF2_ITERATIONS,
      hash: "SHA-256",
    },
    baseKey,
    { name: "AES-CBC", length: KEY_LENGTH * 8 },
    true, // extractable so we can export for token and localStorage
    ["encrypt", "decrypt"]
  );

  return derivedKey;
}

export async function keyToToken(key: CryptoKey): Promise<string> {
  const rawKey = await crypto.subtle.exportKey("raw", key);
  const hashBuffer = await crypto.subtle.digest("SHA-256", rawKey);
  const hashBytes = new Uint8Array(hashBuffer);
  return Array.from(hashBytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export async function exportKey(key: CryptoKey): Promise<string> {
  const rawKey = await crypto.subtle.exportKey("raw", key);
  const bytes = new Uint8Array(rawKey);
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

export async function importKey(b64: string): Promise<CryptoKey> {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }

  return crypto.subtle.importKey(
    "raw",
    bytes,
    { name: "AES-CBC", length: KEY_LENGTH * 8 },
    true,
    ["encrypt", "decrypt"]
  );
}

function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

function base64ToArrayBuffer(b64: string): ArrayBuffer {
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

export async function encryptData(
  key: CryptoKey,
  data: unknown
): Promise<Envelope> {
  const iv = crypto.getRandomValues(new Uint8Array(16));
  const plaintext = new TextEncoder().encode(JSON.stringify(data));

  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-CBC", iv },
    key,
    plaintext
  );

  return {
    iv: arrayBufferToBase64(iv.buffer),
    data: arrayBufferToBase64(ciphertext),
  };
}

export async function decryptData(
  key: CryptoKey,
  envelope: Envelope
): Promise<unknown> {
  const iv = base64ToArrayBuffer(envelope.iv);
  const ciphertext = base64ToArrayBuffer(envelope.data);

  const plaintext = await crypto.subtle.decrypt(
    { name: "AES-CBC", iv },
    key,
    ciphertext
  );

  const text = new TextDecoder().decode(plaintext);
  return JSON.parse(text);
}
