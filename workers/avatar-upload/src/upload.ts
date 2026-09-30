export const MAX_BYTES = 2 * 1024 * 1024;

export function validateJpegRequest(
  contentType: string | null,
  byteLength: number,
): 'ok' | 'invalid_image' {
  const type = (contentType ?? '').split(';')[0].trim().toLowerCase();
  if (type !== 'image/jpeg') return 'invalid_image';
  if (byteLength <= 0 || byteLength > MAX_BYTES) return 'invalid_image';
  return 'ok';
}

export function objectKeyForUid(uid: string): string {
  return `avatars/${uid}.jpg`;
}

export function publicPhotoUrl(publicBaseUrl: string, uid: string): string {
  const base = publicBaseUrl.replace(/\/+$/, '');
  return `${base}/avatars/${uid}.jpg`;
}
