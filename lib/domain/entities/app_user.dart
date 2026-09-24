class AppUser {
  const AppUser({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.avatarId,
  });

  final String uid;
  final String displayName;
  final String? photoUrl;
  final String? avatarId;
}
