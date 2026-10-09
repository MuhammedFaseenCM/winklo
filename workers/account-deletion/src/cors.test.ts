import { describe, expect, it } from 'vitest';
import { corsHeadersFor, isOriginAllowed } from './cors';

describe('cors', () => {
  it('allows Pages + github.io', () => {
    expect(isOriginAllowed('https://winklo.pages.dev')).toBe(true);
    expect(isOriginAllowed('https://muhammedfaseencm.github.io')).toBe(true);
    expect(isOriginAllowed('https://evil.example')).toBe(false);
  });
  it('echoes allowed origin', () => {
    const h = corsHeadersFor('https://winklo.pages.dev');
    expect(h['Access-Control-Allow-Origin']).toBe('https://winklo.pages.dev');
  });
});
