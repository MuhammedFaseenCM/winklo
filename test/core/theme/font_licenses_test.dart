import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/core/theme/font_licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the bundled Malayalam font brings its licence', () async {
    registerFontLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final noto = entries.where(
      (entry) => entry.packages.contains('Noto Sans Malayalam'),
    );
    expect(noto, isNotEmpty);
    final text = noto.first.paragraphs.map((p) => p.text).join('\n');
    expect(text, contains('SIL Open Font License'));
  });
}
