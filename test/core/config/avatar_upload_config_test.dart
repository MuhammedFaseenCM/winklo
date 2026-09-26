import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/config/avatar_upload_config.dart';

void main() {
  test('baseUrl defaults to production Worker and isConfigured is true', () {
    expect(
      AvatarUploadConfig.baseUrl,
      'https://winklo-avatar-upload.winklo.workers.dev',
    );
    expect(AvatarUploadConfig.isConfigured, isTrue);
  });
}
