import { SignJWT, importPKCS8 } from 'jose';

export type ServiceAccount = {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri?: string;
};

const DEFAULT_SCOPES = [
  'https://www.googleapis.com/auth/datastore',
  'https://www.googleapis.com/auth/identitytoolkit',
];

export function parseServiceAccountJson(raw: string): ServiceAccount {
  const parsed = JSON.parse(raw) as ServiceAccount;
  if (!parsed.client_email || !parsed.private_key || !parsed.project_id) {
    throw new Error('invalid_service_account');
  }
  return parsed;
}

export async function getGoogleAccessToken(
  sa: ServiceAccount,
  scopes: string[] = DEFAULT_SCOPES,
): Promise<string> {
  const key = await importPKCS8(sa.private_key, 'RS256');
  const now = Math.floor(Date.now() / 1000);
  const assertion = await new SignJWT({
    scope: scopes.join(' '),
  })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email)
    .setAudience(sa.token_uri || 'https://oauth2.googleapis.com/token')
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
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
  const json = JSON.parse(text) as { access_token?: string };
  if (!json.access_token) throw new Error('token_exchange_failed:missing');
  return json.access_token;
}
