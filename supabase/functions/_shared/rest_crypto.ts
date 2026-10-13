type RestEnvelope = {
  data?: string;
  iv?: string;
  sig?: string;
};

type Payload = Record<string, unknown>;

const encoder = new TextEncoder();
const decoder = new TextDecoder();

function fromHex(value: string, name: string, minBytes: number): Uint8Array {
  if (
    value.length % 2 !== 0 ||
    value.length < minBytes * 2 ||
    !/^[0-9a-f]+$/i.test(value)
  ) {
    throw new Error(`${name} must be valid hex with at least ${minBytes} bytes`);
  }
  return Uint8Array.from(
    value.match(/.{2}/g)!.map((byte) => Number.parseInt(byte, 16)),
  );
}

function fromBase64(value: string): Uint8Array {
  return Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
}

function toBase64(value: Uint8Array): string {
  let binary = "";
  for (const byte of value) binary += String.fromCharCode(byte);
  return btoa(binary);
}

function toHex(value: Uint8Array): string {
  return Array.from(value, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function getKeys() {
  const aesHex = Deno.env.get("REST_ENCRYPT_KEY") ?? "";
  const hmacHex = Deno.env.get("REST_HMAC_KEY") ?? "";
  if (aesHex.length !== 64) {
    throw new Error("REST_ENCRYPT_KEY must be exactly 32 bytes (64 hex characters)");
  }

  const aesKey = await crypto.subtle.importKey(
    "raw",
    fromHex(aesHex, "REST_ENCRYPT_KEY", 32),
    { name: "AES-CBC" },
    false,
    ["encrypt", "decrypt"],
  );
  const hmacKey = await crypto.subtle.importKey(
    "raw",
    fromHex(hmacHex, "REST_HMAC_KEY", 32),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
  return { aesKey, hmacKey };
}

export async function decryptPayload(envelope: RestEnvelope): Promise<Payload> {
  if (!envelope.data || !envelope.iv || !envelope.sig) {
    throw new Error("Malformed encrypted payload");
  }
  const { aesKey, hmacKey } = await getKeys();
  const iv = fromBase64(envelope.iv);
  const ciphertext = fromBase64(envelope.data);
  if (iv.length !== 16) throw new Error("Encrypted payload has an invalid IV");

  const signature = fromHex(envelope.sig, "payload signature", 32);
  const signedData = encoder.encode(`${envelope.iv}.${envelope.data}`);
  const validSignature = await crypto.subtle.verify(
    "HMAC",
    hmacKey,
    signature,
    signedData,
  );
  if (!validSignature) throw new Error("Encrypted payload signature mismatch");

  const plaintext = await crypto.subtle.decrypt(
    { name: "AES-CBC", iv },
    aesKey,
    ciphertext,
  );
  const payload: unknown = JSON.parse(decoder.decode(plaintext));
  if (payload === null || typeof payload !== "object" || Array.isArray(payload)) {
    throw new Error("Encrypted payload must contain a JSON object");
  }
  return payload as Payload;
}

export async function encryptPayload(
  payload: Payload,
): Promise<Required<RestEnvelope>> {
  const { aesKey, hmacKey } = await getKeys();
  const iv = crypto.getRandomValues(new Uint8Array(16));
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-CBC", iv },
    aesKey,
    encoder.encode(JSON.stringify(payload)),
  );
  const ivBase64 = toBase64(iv);
  const dataBase64 = toBase64(new Uint8Array(ciphertext));
  const signature = await crypto.subtle.sign(
    "HMAC",
    hmacKey,
    encoder.encode(`${ivBase64}.${dataBase64}`),
  );

  return {
    data: dataBase64,
    iv: ivBase64,
    sig: toHex(new Uint8Array(signature)),
  };
}
