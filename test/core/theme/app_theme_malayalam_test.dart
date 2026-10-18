import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:winklo/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const regular = 'NotoSansMalayalam_regular';
  const bold = 'NotoSansMalayalam_700';

  test('every text theme style falls back to Noto Sans Malayalam', () {
    final theme = buildAppTheme().textTheme;
    final styles = [
      theme.displayLarge,
      theme.displayMedium,
      theme.displaySmall,
      theme.headlineLarge,
      theme.headlineMedium,
      theme.headlineSmall,
      theme.titleLarge,
      theme.titleMedium,
      theme.titleSmall,
      theme.bodyLarge,
      theme.bodyMedium,
      theme.bodySmall,
      theme.labelLarge,
      theme.labelMedium,
      theme.labelSmall,
    ];
    for (final style in styles) {
      expect(style!.fontFamily, startsWith('Lexend'));
      expect(style.fontFamilyFallback, contains('Lexend'));
      expect(
        style.fontFamilyFallback!.last,
        anyOf(regular, bold),
        reason: '$style',
      );
    }
  });

  test('heavy styles fall back to the Bold file', () {
    final theme = buildAppTheme().textTheme;
    expect(theme.titleLarge!.fontFamilyFallback!.last, bold); // w700
    expect(theme.bodyMedium!.fontFamilyFallback!.last, regular); // w400
  });

  test('the Lexend styles set outside the text theme fall back too', () {
    final theme = buildAppTheme();
    expect(
      theme.appBarTheme.titleTextStyle!.fontFamilyFallback,
      contains(bold),
    );
    expect(
      theme.filledButtonTheme.style!.textStyle!.resolve({})!.fontFamilyFallback,
      contains(bold),
    );
    expect(
      theme.segmentedButtonTheme.style!.textStyle!
          .resolve({})!
          .fontFamilyFallback,
      contains(regular),
    );
    expect(withMalayalamFallback(GoogleFonts.lexend()).fontFamilyFallback, [
      'Lexend',
      regular,
    ]);
  });
}
