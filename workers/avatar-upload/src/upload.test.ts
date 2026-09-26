import { describe, expect, it } from 'vitest';
import {
  objectKeyForUid,
  publicPhotoUrl,
  validateJpegRequest,
} from './upload';

describe('validateJpegRequest', () => {
  it('accepts image/jpeg under limit', () => {
    expect(validateJpegRequest('image/jpeg', 100)).toBe('ok');
  });
  it('rejects wrong type', () => {
    expect(validateJpegRequest('image/png', 100)).toBe('invalid_image');
  });
  it('rejects oversized', () => {
    expect(validateJpegRequest('image/jpeg', 3 * 1024 * 1024)).toBe(
      'invalid_image',
    );
  });
});

describe('keys', () => {
  it('builds object key and public URL', () => {
    expect(objectKeyForUid('u1')).toBe('avatars/u1.jpg');
    expect(publicPhotoUrl('https://pub.example/', 'u1')).toBe(
      'https://pub.example/avatars/u1.jpg',
    );
  });
});
