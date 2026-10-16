import { SignJWT, importPKCS8 } from 'jose';

// Same token exchange as workers/leaderboard/src/google_auth.ts, with only the
// Firestore scope, and the token kept for the isolate's lifetime.

export type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri?: string;
};

const SCOPES = ['https://www.googleapis.com/auth/datastore'];

/** Refresh this long before the token's expiry. */
const EXPIRY_MARGIN_MS = 5 * 60 * 1000;

let cached: { token: string; expiresAt: number; key: string } | null = null;

export function parseServiceAccountJson(raw: string): ServiceAccount {
  const parsed = JSON.parse(raw) as ServiceAccount;
  if (!parsed.client_email || !parsed.private_key || !parsed.project_id) {
    throw new Error('invalid_service_account');
  }
  return parsed;
}

export async function getGoogleAccessToken(
  sa: ServiceAccount,
  now: () => number = Date.now,
): Promise<string> {
  if (cached && cached.key === sa.client_email && cached.expiresAt - EXPIRY_MARGIN_MS > now()) {
    return cached.token;
  }
  const key = await importPKCS8(sa.private_key, 'RS256');
  const issuedAt = Math.floor(now() / 1000);
  const assertion = await new SignJWT({ scope: SCOPES.join(' ') })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email)
    .setAudience(sa.token_uri || 'https://oauth2.googleapis.com/token')
    .setIssuedAt(issuedAt)
    .setExpirationTime(issuedAt + 3600)
    .sign(key);

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  const text = await res.text();
  if (!res.ok) {
    throw new Error(`token_exchange_failed:${res.status}:${text.slice(0, 200)}`);
  }
  const json = JSON.parse(text) as { access_token?: string; expires_in?: number };
  if (!json.access_token) throw new Error('token_exchange_failed:missing');
  cached = {
    token: json.access_token,
    expiresAt: now() + (json.expires_in ?? 3600) * 1000,
    key: sa.client_email,
  };
  return json.access_token;
}
