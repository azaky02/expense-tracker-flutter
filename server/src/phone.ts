import crypto from 'node:crypto';
import { config } from './config.ts';
import type { Tx } from './db.ts';

/**
 * One canonical form per phone number so "0100 123 4567", "+201001234567" and "00201001234567"
 * are the same account: separators removed, 00 → +, and Egyptian +20 numbers written locally (0…).
 */
export function normalizePhone(input: string): string {
  let p = input.trim().replace(/[\s\-().]/g, '');
  p = p.replace(/[٠-٩]/g, (d) => String('٠١٢٣٤٥٦٧٨٩'.indexOf(d)));
  if (p.startsWith('00')) p = '+' + p.slice(2);
  if (p.startsWith('+20')) p = '0' + p.slice(3);
  return p;
}

export const isValidPhone = (p: string) => /^\+?\d{8,15}$/.test(p);

const OTP_TTL_SEC = 5 * 60;
const MAX_ATTEMPTS = 5;
const hashCode = (phone: string, code: string) => crypto.createHash('sha256').update(`${phone}:${code}`).digest('hex');

/**
 * Creates a 6-digit code for [phone]. No SMS provider is configured yet, so while OTP_DEV_MODE is
 * on the code is returned to the caller and the app shows it on screen.
 */
export async function createOtp(tx: Tx, phone: string, purpose: string) {
  const code = String(crypto.randomInt(0, 1_000_000)).padStart(6, '0');
  await tx.query('UPDATE otp_codes SET consumed_at = now() WHERE phone = $1 AND purpose = $2 AND consumed_at IS NULL', [phone, purpose]);
  await tx.query(
    `INSERT INTO otp_codes (id, phone, purpose, code_hash, expires_at) VALUES ($1,$2,$3,$4, now() + ($5 || ' seconds')::interval)`,
    [crypto.randomUUID(), phone, purpose, hashCode(phone, code), String(OTP_TTL_SEC)],
  );
  return { expiresIn: OTP_TTL_SEC, devCode: config.otpDevMode ? code : undefined };
}

/** Checks and consumes the latest code. Returns null when valid, otherwise the error code. */
export async function verifyOtp(tx: Tx, phone: string, purpose: string, code: string): Promise<string | null> {
  const row = (
    await tx.query(
      `SELECT id, code_hash, attempts, expires_at < now() AS expired FROM otp_codes
        WHERE phone = $1 AND purpose = $2 AND consumed_at IS NULL ORDER BY created_at DESC LIMIT 1 FOR UPDATE`,
      [phone, purpose],
    )
  ).rows[0];
  if (!row) return 'invalid_otp';
  if (row.expired) return 'otp_expired';
  if (row.attempts >= MAX_ATTEMPTS) return 'too_many_attempts';
  const expected = Buffer.from(row.code_hash, 'hex');
  const given = Buffer.from(hashCode(phone, code), 'hex');
  if (!crypto.timingSafeEqual(expected, given)) {
    await tx.query('UPDATE otp_codes SET attempts = attempts + 1 WHERE id = $1', [row.id]);
    return 'invalid_otp';
  }
  await tx.query('UPDATE otp_codes SET consumed_at = now() WHERE id = $1', [row.id]);
  return null;
}
