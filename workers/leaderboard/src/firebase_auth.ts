import { createRemoteJWKSet, jwtVerify } from 'jose';

const JWKS = createRemoteJWKSet(
  new URL(
    'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
  ),
);

export async function verifyFirebaseIdToken(
  token: string,
  projectId: string,
): Promise<{ uid: string; email: string | null }> {
  const { payload } = await jwtVerify(token, JWKS, {
    issuer: `https://securetoken.google.com/${projectId}`,
    audience: projectId,
  });
  const uid = payload.sub;
  if (!uid) throw new Error('missing sub');
  const email =
    typeof payload.email === 'string' ? payload.email : null;
  return { uid, email };
}
