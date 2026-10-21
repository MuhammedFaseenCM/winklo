/// The font family for numbers and letters painted straight onto a game
/// board's canvas (the Flame boards draw with TextPainter, outside the
/// widget theme).
///
/// Null, the default, is the platform's sans, as on a phone. Code that
/// renders boards inside `flutter test` (the promo capture) sets a loaded
/// family, because the test engine draws every glyph of its default font as
/// a box and no font registration can replace it.
abstract final class BoardText {
  static String? family;
}
