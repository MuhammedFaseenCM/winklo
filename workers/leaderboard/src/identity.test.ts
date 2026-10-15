import { describe, expect, it } from 'vitest';
import {
  AVATAR_ID_MAX_LENGTH,
  DISPLAY_NAME_MAX_LENGTH,
  cleanAvatarId,
  cleanDisplayName,
  cleanPhotoUrl,
} from './identity';

describe('cleanDisplayName', () => {
  it('trims and keeps short names', () => {
    expect(cleanDisplayName('  Ada  ')).toBe('Ada');
  });

  it('falls back to Player when blank', () => {
    expect(cleanDisplayName('   ')).toBe('Player');
  });

  it('cuts long names to the limit', () => {
    expect(cleanDisplayName('x'.repeat(100))).toHaveLength(DISPLAY_NAME_MAX_LENGTH);
  });

  it('never splits a surrogate pair', () => {
    expect(cleanDisplayName(`${'a'.repeat(39)}😀tail`)).toBe('a'.repeat(39));
  });
});

describe('cleanPhotoUrl', () => {
  it('keeps Google account photos and our R2 avatars', () => {
    for (const url of [
      'https://lh3.googleusercontent.com/a/ACg8oc=s96-c',
      'https://pub-94fd8286c7fa4508a0e988821039d2a8.r2.dev/avatars/u1.jpg',
    ]) {
      expect(cleanPhotoUrl(url)).toBe(url);
    }
  });

  it('drops other hosts, plain http, look-alikes, overlong and non-strings', () => {
    for (const url of [
      'https://example.com/a.jpg',
      'http://lh3.googleusercontent.com/a/b',
      'https://lh3.googleusercontent.com.evil.example/a',
      'https://pub-94fd8286c7fa4508a0e988821039d2a8.r2.dev/other/u1.jpg',
      `https://lh3.googleusercontent.com/${'a'.repeat(2100)}`,
      'https://lh3.googleusercontent.com/a\nb',
      null,
      undefined,
      42,
    ]) {
      expect(cleanPhotoUrl(url)).toBeNull();
    }
  });
});

describe('cleanAvatarId', () => {
  it('keeps preset ids and drops blank or overlong ones', () => {
    expect(cleanAvatarId('preset_01')).toBe('preset_01');
    expect(cleanAvatarId('')).toBeNull();
    expect(cleanAvatarId(null)).toBeNull();
    expect(cleanAvatarId(7)).toBeNull();
    expect(cleanAvatarId('a'.repeat(AVATAR_ID_MAX_LENGTH + 1))).toBeNull();
  });
});
