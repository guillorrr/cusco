const UNIT_MS: Record<string, number> = {
  s: 1000,
  m: 60 * 1000,
  h: 60 * 60 * 1000,
  d: 24 * 60 * 60 * 1000,
};

/**
 * Parses an ms-style duration ("30s", "15m", "1h", "7d") into milliseconds.
 *
 * The format matches what the JWT signer accepts, so a single constant can
 * drive both the access token TTL (handed to the signer) and the refresh token
 * TTL (stored as an absolute `expires_at`).
 */
export function parseDuration(value: string): number {
  const match = /^(\d+)([smhd])$/.exec(value);
  if (!match) {
    throw new Error(`Invalid duration "${value}": expected a number followed by s, m, h or d.`);
  }
  return Number(match[1]) * UNIT_MS[match[2]];
}
