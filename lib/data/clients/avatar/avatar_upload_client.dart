abstract class AvatarUploadClient {
  Future<Uri> uploadJpeg({required String idToken, required List<int> bytes});
}
