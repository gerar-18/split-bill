import * as crypto from 'crypto';

const CROCKFORD_ALPHABET = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const SHARE_CODE_LENGTH = 8;
const SHARE_CODE_REGEX = /^[0-9A-HJKMNP-TV-Z]{8}$/;

/**
 * Strips HTML tags, stray angle brackets, and ASCII control characters,
 * collapses extra whitespace, and enforces a strict maximum character length for UGC safety.
 */
export function sanitizeUserText(input: string, maxLength: number): string {
  const withoutControls = input.replace(/[\u0000-\u001F\u007F]/g, ' ');
  const withoutHtml = withoutControls.replace(/<[^>]*>/g, '').replace(/[<>]/g, '');
  const collapsed = withoutHtml.replace(/\s+/g, ' ').trim();
  return collapsed.slice(0, maxLength);
}

/**
 * Validates that a base64 string decodes to genuine JPEG or PNG image bytes
 * (blocking disguised HTML/SVG/JS uploads).
 */
export function isValidImageBase64(rawBase64: string): boolean {
  const trimmed = rawBase64.trim();
  if (!trimmed || !/^[A-Za-z0-9+/=]+$/.test(trimmed) || trimmed.length % 4 !== 0) {
    return false;
  }

  const headerSlice = trimmed.slice(0, 24);
  const bytes = Buffer.from(headerSlice, 'base64');
  if (bytes.length < 4) {
    return false;
  }

  const isJpeg = bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  const isPng =
    bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a;

  return isJpeg || isPng;
}

/**
 * Generates an 8-character Crockford Base32 share code (keyspace 32^8 ~ 1.1 trillion)
 * using cryptographically secure random bytes.
 */
export function generateShareCode(): string {
  const bytes = crypto.randomBytes(SHARE_CODE_LENGTH);
  let code = '';
  for (let i = 0; i < SHARE_CODE_LENGTH; i++) {
    code += CROCKFORD_ALPHABET[bytes[i] % CROCKFORD_ALPHABET.length];
  }
  return code;
}

export function normalizeShareCode(raw: string): string {
  return raw.trim().toUpperCase();
}

export function isValidShareCode(code: string): boolean {
  return SHARE_CODE_REGEX.test(normalizeShareCode(code));
}

/**
 * Generates a high-entropy 256-bit ephemeral capability token.
 */
export function generateCapabilityToken(): string {
  return crypto.randomBytes(32).toString('base64url');
}

/**
 * Computes the SHA-256 hex digest of a raw token for hash-at-rest storage.
 */
export function sha256Hex(rawToken: string): string {
  return crypto.createHash('sha256').update(rawToken, 'utf8').digest('hex');
}

/**
 * Constant-time hex string comparison to prevent timing side-channels.
 */
export function timingSafeEqualHex(a: string, b: string): boolean {
  if (a.length !== b.length || a.length === 0) {
    return false;
  }
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  if (bufA.length !== bufB.length) {
    return false;
  }
  return crypto.timingSafeEqual(bufA, bufB);
}
