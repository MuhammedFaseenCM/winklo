export const LEADERBOARD_GAMES = ['zip', 'path_words', 'sudoku'] as const;

export function avatarObjectKey(uid: string): string {
  return `avatars/${uid}.jpg`;
}

export function userDocPath(projectId: string, uid: string): string {
  return `projects/${projectId}/databases/(default)/documents/users/${encodeURIComponent(uid)}`;
}
