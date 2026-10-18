/**
 * The public name and photo written onto entries, cleaned to what the rules'
 * `validLeaderboardIdentity` accepts. `lib/data/leaderboard_identity.dart` is
 * the app's copy; `test/firestore` pins the two together.
 */

export const DISPLAY_NAME_MAX_LENGTH = 40;
export const AVATAR_ID_MAX_LENGTH = 64;
const PHOTO_URL_MAX_LENGTH = 2048;

/** Google account photos and our R2 avatars; any other host would see who opens the board. */
export const PHOTO_URL_PATTERN =
  '^https://([a-z0-9-]+[.]googleusercontent[.]com|pub-94fd8286c7fa4508a0e988821039d2a8[.]r2[.]dev/avatars)/.*$';

const photoUrl = new RegExp(PHOTO_URL_PATTERN);

/** [name] trimmed and cut to 40 UTF-16 units without splitting a pair; `Player` when blank. */
export function cleanDisplayName(name: string): string {
  const trimmed = name.trim();
  if (!trimmed) return 'Player';
  if (trimmed.length <= DISPLAY_NAME_MAX_LENGTH) return trimmed;
  let end = DISPLAY_NAME_MAX_LENGTH;
  const last = trimmed.charCodeAt(end - 1);
  if (last >= 0xd800 && last <= 0xdbff) end -= 1;
  return trimmed.slice(0, end).trimEnd();
}

export function cleanPhotoUrl(url: unknown): string | null {
  if (typeof url !== 'string' || url.length > PHOTO_URL_MAX_LENGTH) return null;
  return photoUrl.test(url) ? url : null;
}

export function cleanAvatarId(avatarId: unknown): string | null {
  if (typeof avatarId !== 'string' || !avatarId) return null;
  return avatarId.length <= AVATAR_ID_MAX_LENGTH ? avatarId : null;
}

export type Identity = {
  displayName: string;
  photoUrl: string | null;
  avatarId: string | null;
};

/**
 * The identity to write, or null when the app didn't know it (its profile
 * read failed), so the stored name and photo stay as they are.
 */
export function cleanIdentity(body: {
  displayName?: unknown;
  photoUrl?: unknown;
  avatarId?: unknown;
}): Identity | null {
  if (typeof body.displayName !== 'string') return null;
  return {
    displayName: cleanDisplayName(body.displayName),
    photoUrl: cleanPhotoUrl(body.photoUrl),
    avatarId: cleanAvatarId(body.avatarId),
  };
}
