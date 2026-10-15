import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Noto Sans Malayalam ships in `assets/google_fonts/` under the SIL Open
/// Font License, which asks for the licence to travel with the font.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Noto Sans Malayalam'], license);
  });
}
