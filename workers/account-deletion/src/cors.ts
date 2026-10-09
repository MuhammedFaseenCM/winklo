export const ALLOWED_ORIGINS = [
  'https://winklo.pages.dev',
  'https://muhammedfaseencm.github.io',
] as const;

export function isOriginAllowed(origin: string | null): boolean {
  return !!origin && (ALLOWED_ORIGINS as readonly string[]).includes(origin);
}

export function corsHeadersFor(origin: string | null): Record<string, string> {
  const allow = isOriginAllowed(origin) ? origin! : ALLOWED_ORIGINS[0];
  return {
    'Access-Control-Allow-Origin': allow,
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    Vary: 'Origin',
  };
}
