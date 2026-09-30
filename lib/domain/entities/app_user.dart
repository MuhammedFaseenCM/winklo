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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppUser &&
        other.uid == uid &&
        other.displayName == displayName &&
        other.photoUrl == photoUrl &&
        other.avatarId == avatarId;
  }

  @override
  int get hashCode => Object.hash(uid, displayName, photoUrl, avatarId);
}
