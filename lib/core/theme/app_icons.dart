import 'package:flutter/widgets.dart';

const _duotone = 'PhosphorDuotone';
const _fill = 'PhosphorFill';
const _regular = 'PhosphorRegular';

/// Every icon the app draws: Phosphor 2.1 duotone, with a few filled glyphs
/// for selected states. Screens name icons here, never `Icons.*`, and draw
/// them with `AppIcon` so a duotone glyph's fill layer shows too.
///
/// The fonts are vendored in `assets/fonts/phosphor/`. To add an icon, look
/// up its codepoint in Phosphor 2.1 (the `phosphor_flutter` 2.1.0 sources
/// list every style's codepoints) and, for a duotone glyph, add its fill
/// layer to [_duotoneFills].
abstract final class AppIcons {
  // Navigation
  /// Phosphor `house`, duotone.
  static const home = IconData(0xe2c3, fontFamily: _duotone);

  /// Phosphor `house`, fill.
  static const homeSelected = IconData(0xe2c2, fontFamily: _fill);

  /// Phosphor `trophy`, duotone.
  static const trophy = IconData(0xe67f, fontFamily: _duotone);

  /// Phosphor `trophy`, fill.
  static const trophySelected = IconData(0xe67e, fontFamily: _fill);

  /// Phosphor `user`, duotone.
  static const user = IconData(0xe4c3, fontFamily: _duotone);

  /// Phosphor `user`, fill.
  static const userSelected = IconData(0xe4c2, fontFamily: _fill);

  /// Phosphor `arrow-left`, duotone.
  static const back = IconData(0xe059, fontFamily: _duotone);

  /// Phosphor `caret-left`, duotone.
  static const chevronLeft = IconData(0xe139, fontFamily: _duotone);

  /// Phosphor `caret-right`, duotone.
  static const chevronRight = IconData(0xe13b, fontFamily: _duotone);

  /// Phosphor `caret-down`, regular.
  static const expand = IconData(0xe136, fontFamily: _regular);

  /// Phosphor `x`, duotone.
  static const close = IconData(0xe4f7, fontFamily: _duotone);

  /// Phosphor `arrow-square-out`, duotone.
  static const openExternal = IconData(0xe5df, fontFamily: _duotone);

  // Games
  /// Phosphor `lightning`, duotone.
  static const lightning = IconData(0xe2df, fontFamily: _duotone);

  /// Phosphor `path`, duotone.
  static const path = IconData(0xe39d, fontFamily: _duotone);

  /// Phosphor `grid-four`, duotone.
  static const grid = IconData(0xe297, fontFamily: _duotone);

  /// Phosphor `text-aa`, duotone.
  static const textAa = IconData(0xe6ef, fontFamily: _duotone);

  /// Phosphor `arrows-left-right`, duotone.
  static const swap = IconData(0xe0a1, fontFamily: _duotone);

  /// Phosphor `cards`, duotone.
  static const cards = IconData(0xe0f9, fontFamily: _duotone);

  /// Phosphor `dice-five`, duotone.
  static const dice = IconData(0xe1ef, fontFamily: _duotone);

  /// Phosphor `infinity`, duotone.
  static const infinity = IconData(0xe635, fontFamily: _duotone);

  /// Phosphor `compass`, duotone.
  static const compass = IconData(0xe1c9, fontFamily: _duotone);

  /// Phosphor `book-open`, duotone.
  static const book = IconData(0xe0e7, fontFamily: _duotone);

  /// Phosphor `backspace`, duotone.
  static const backspace = IconData(0xe0af, fontFamily: _duotone);

  /// Phosphor `prohibit`, duotone.
  static const prohibit = IconData(0xe3df, fontFamily: _duotone);

  /// Phosphor `sparkle`, duotone.
  static const sparkle = IconData(0xe6a3, fontFamily: _duotone);

  // Play controls
  /// Phosphor `play`, duotone.
  static const play = IconData(0xe3d1, fontFamily: _duotone);

  /// Phosphor `pause-circle`, duotone.
  static const pause = IconData(0xe3a1, fontFamily: _duotone);

  /// Phosphor `arrow-clockwise`, duotone.
  static const refresh = IconData(0xe037, fontFamily: _duotone);

  /// Phosphor `arrow-counter-clockwise`, duotone.
  static const replay = IconData(0xe039, fontFamily: _duotone);

  /// Phosphor `arrow-u-up-left`, duotone.
  static const undo = IconData(0xe08b, fontFamily: _duotone);

  /// Phosphor `lightbulb`, duotone.
  static const hint = IconData(0xe2dd, fontFamily: _duotone);

  /// Phosphor `question`, duotone.
  static const help = IconData(0xe3eb, fontFamily: _duotone);

  /// Phosphor `timer`, duotone.
  static const timer = IconData(0xe493, fontFamily: _duotone);

  /// Phosphor `clock`, duotone.
  static const clock = IconData(0xe19b, fontFamily: _duotone);

  /// Phosphor `paper-plane-tilt`, duotone.
  static const send = IconData(0xe399, fontFamily: _duotone);

  /// Phosphor `note-pencil`, duotone.
  static const editNote = IconData(0xe34d, fontFamily: _duotone);

  // Progress and rewards
  /// Phosphor `fire`, duotone.
  static const streak = IconData(0xe243, fontFamily: _duotone);

  /// Phosphor `snowflake`, duotone.
  static const freeze = IconData(0xe5ab, fontFamily: _duotone);

  /// Phosphor `brain`, duotone.
  static const noHints = IconData(0xe74f, fontFamily: _duotone);

  /// Phosphor `seal-check`, duotone.
  static const flawless = IconData(0xe607, fontFamily: _duotone);

  /// Phosphor `crown-simple`, duotone.
  static const crown = IconData(0xe617, fontFamily: _duotone);

  /// Phosphor `medal`, duotone.
  static const medal = IconData(0xe321, fontFamily: _duotone);

  /// Phosphor `ranking`, duotone.
  static const ranking = IconData(0xed63, fontFamily: _duotone);

  /// Phosphor `chart-line-up`, duotone.
  static const insights = IconData(0xe157, fontFamily: _duotone);

  /// Phosphor `star`, fill.
  static const star = IconData(0xe46a, fontFamily: _fill);

  /// Phosphor `star`, regular.
  static const starOutline = IconData(0xe46a, fontFamily: _regular);

  /// Phosphor `check`, duotone.
  static const check = IconData(0xe183, fontFamily: _duotone);

  /// Phosphor `check-circle`, duotone.
  static const checkCircle = IconData(0xe185, fontFamily: _duotone);

  /// Phosphor `circle`, duotone.
  static const circle = IconData(0xe18b, fontFamily: _duotone);

  /// Phosphor `lock`, duotone.
  static const lock = IconData(0xe2fb, fontFamily: _duotone);

  /// Phosphor `sun`, duotone.
  static const sun = IconData(0xe473, fontFamily: _duotone);

  // Calendar
  /// Phosphor `calendar-blank`, duotone.
  static const calendar = IconData(0xe10b, fontFamily: _duotone);

  /// Phosphor `calendar-dot`, duotone.
  static const today = IconData(0xe7b3, fontFamily: _duotone);

  /// Phosphor `calendar-dots`, duotone.
  static const week = IconData(0xe7b5, fontFamily: _duotone);

  // People and leagues
  /// Phosphor `globe-hemisphere-west`, duotone.
  static const globe = IconData(0xe28d, fontFamily: _duotone);

  /// Phosphor `users-three`, duotone.
  static const group = IconData(0xe68f, fontFamily: _duotone);

  /// Phosphor `user-plus`, duotone.
  static const groupAdd = IconData(0xe4d1, fontFamily: _duotone);

  /// Phosphor `user-minus`, duotone.
  static const userRemove = IconData(0xe4cf, fontFamily: _duotone);

  /// Phosphor `identification-badge`, duotone.
  static const nameBadge = IconData(0xe6f7, fontFamily: _duotone);

  /// Phosphor `key`, duotone.
  static const key = IconData(0xe2d7, fontFamily: _duotone);

  /// Phosphor `crosshair`, duotone.
  static const locate = IconData(0xe1d7, fontFamily: _duotone);

  /// Phosphor `share-network`, duotone.
  static const share = IconData(0xe40b, fontFamily: _duotone);

  /// Phosphor `copy`, duotone.
  static const copy = IconData(0xe1cb, fontFamily: _duotone);

  /// Phosphor `pencil-simple`, duotone.
  static const edit = IconData(0xe3b5, fontFamily: _duotone);

  /// Phosphor `plus`, duotone.
  static const add = IconData(0xe3d5, fontFamily: _duotone);

  /// Phosphor `trash`, duotone.
  static const delete = IconData(0xe4a7, fontFamily: _duotone);

  /// Phosphor `sign-out`, duotone.
  static const signOut = IconData(0xe42b, fontFamily: _duotone);

  /// Phosphor `images`, duotone.
  static const photos = IconData(0xe837, fontFamily: _duotone);

  // Settings and system
  /// Phosphor `sliders-horizontal`, duotone.
  static const tune = IconData(0xe435, fontFamily: _duotone);

  /// Phosphor `speaker-high`, duotone.
  static const sound = IconData(0xe44b, fontFamily: _duotone);

  /// Phosphor `vibrate`, duotone.
  static const vibrate = IconData(0xe4d9, fontFamily: _duotone);

  /// Phosphor `megaphone`, duotone.
  static const announce = IconData(0xe325, fontFamily: _duotone);

  /// Phosphor `shield-check`, duotone.
  static const privacy = IconData(0xe40f, fontFamily: _duotone);

  /// Phosphor `shield`, duotone.
  static const shield = IconData(0xe40d, fontFamily: _duotone);

  /// Phosphor `info`, duotone.
  static const info = IconData(0xe2cf, fontFamily: _duotone);

  /// Phosphor `flag`, duotone.
  static const flag = IconData(0xe245, fontFamily: _duotone);

  /// Phosphor `download-simple`, duotone.
  static const download = IconData(0xe20d, fontFamily: _duotone);

  /// Phosphor `cloud-arrow-down`, duotone.
  static const downloading = IconData(0xe1ad, fontFamily: _duotone);

  /// Phosphor `arrow-circle-up`, duotone.
  static const update = IconData(0xe031, fontFamily: _duotone);

  /// Phosphor `cloud-slash`, duotone.
  static const offline = IconData(0xe1b7, fontFamily: _duotone);

  /// The faint fill layer drawn under duotone [icon], or null when [icon]
  /// isn't a duotone glyph.
  static IconData? duotoneFill(IconData icon) {
    if (icon.fontFamily != _duotone) return null;
    return _duotoneFills[icon.codePoint];
  }

  /// A duotone outline's codepoint → its fill layer. Const, like every
  /// IconData here, so release builds can tree-shake the icon fonts.
  static const Map<int, IconData> _duotoneFills = {
    0xe031: IconData(0xe030, fontFamily: _duotone), // arrow-circle-up
    0xe037: IconData(0xe036, fontFamily: _duotone), // arrow-clockwise
    0xe039: IconData(0xe038, fontFamily: _duotone), // arrow-counter-clockwise
    0xe059: IconData(0xe058, fontFamily: _duotone), // arrow-left
    0xe08b: IconData(0xe08a, fontFamily: _duotone), // arrow-u-up-left
    0xe0a1: IconData(0xe0a0, fontFamily: _duotone), // arrows-left-right
    0xe0af: IconData(0xe0ae, fontFamily: _duotone), // backspace
    0xe0e7: IconData(0xe0e6, fontFamily: _duotone), // book-open
    0xe0f9: IconData(0xe0f8, fontFamily: _duotone), // cards
    0xe10b: IconData(0xe10a, fontFamily: _duotone), // calendar-blank
    0xe139: IconData(0xe138, fontFamily: _duotone), // caret-left
    0xe13b: IconData(0xe13a, fontFamily: _duotone), // caret-right
    0xe157: IconData(0xe156, fontFamily: _duotone), // chart-line-up
    0xe183: IconData(0xe182, fontFamily: _duotone), // check
    0xe185: IconData(0xe184, fontFamily: _duotone), // check-circle
    0xe18b: IconData(0xe18a, fontFamily: _duotone), // circle
    0xe19b: IconData(0xe19a, fontFamily: _duotone), // clock
    0xe1ad: IconData(0xe1ac, fontFamily: _duotone), // cloud-arrow-down
    0xe1b7: IconData(0xe1b6, fontFamily: _duotone), // cloud-slash
    0xe1c9: IconData(0xe1c8, fontFamily: _duotone), // compass
    0xe1cb: IconData(0xe1ca, fontFamily: _duotone), // copy
    0xe1d7: IconData(0xe1d6, fontFamily: _duotone), // crosshair
    0xe1ef: IconData(0xe1ee, fontFamily: _duotone), // dice-five
    0xe20d: IconData(0xe20c, fontFamily: _duotone), // download-simple
    0xe243: IconData(0xe242, fontFamily: _duotone), // fire
    0xe245: IconData(0xe244, fontFamily: _duotone), // flag
    0xe28d: IconData(0xe28c, fontFamily: _duotone), // globe-hemisphere-west
    0xe297: IconData(0xe296, fontFamily: _duotone), // grid-four
    0xe2c3: IconData(0xe2c2, fontFamily: _duotone), // house
    0xe2cf: IconData(0xe2ce, fontFamily: _duotone), // info
    0xe2d7: IconData(0xe2d6, fontFamily: _duotone), // key
    0xe2dd: IconData(0xe2dc, fontFamily: _duotone), // lightbulb
    0xe2df: IconData(0xe2de, fontFamily: _duotone), // lightning
    0xe2fb: IconData(0xe2fa, fontFamily: _duotone), // lock
    0xe321: IconData(0xe320, fontFamily: _duotone), // medal
    0xe325: IconData(0xe324, fontFamily: _duotone), // megaphone
    0xe34d: IconData(0xe34c, fontFamily: _duotone), // note-pencil
    0xe399: IconData(0xe398, fontFamily: _duotone), // paper-plane-tilt
    0xe39d: IconData(0xe39c, fontFamily: _duotone), // path
    0xe3a1: IconData(0xe3a0, fontFamily: _duotone), // pause-circle
    0xe3b5: IconData(0xe3b4, fontFamily: _duotone), // pencil-simple
    0xe3d1: IconData(0xe3d0, fontFamily: _duotone), // play
    0xe3d5: IconData(0xe3d4, fontFamily: _duotone), // plus
    0xe3df: IconData(0xe3de, fontFamily: _duotone), // prohibit
    0xe3eb: IconData(0xe3e8, fontFamily: _duotone), // question
    0xe40b: IconData(0xe408, fontFamily: _duotone), // share-network
    0xe40d: IconData(0xe40a, fontFamily: _duotone), // shield
    0xe40f: IconData(0xe40c, fontFamily: _duotone), // shield-check
    0xe42b: IconData(0xe42a, fontFamily: _duotone), // sign-out
    0xe435: IconData(0xe434, fontFamily: _duotone), // sliders-horizontal
    0xe44b: IconData(0xe44a, fontFamily: _duotone), // speaker-high
    0xe473: IconData(0xe472, fontFamily: _duotone), // sun
    0xe493: IconData(0xe492, fontFamily: _duotone), // timer
    0xe4a7: IconData(0xe4a6, fontFamily: _duotone), // trash
    0xe4c3: IconData(0xe4c2, fontFamily: _duotone), // user
    0xe4cf: IconData(0xe4ce, fontFamily: _duotone), // user-minus
    0xe4d1: IconData(0xe4d0, fontFamily: _duotone), // user-plus
    0xe4d9: IconData(0xe4d8, fontFamily: _duotone), // vibrate
    0xe4f7: IconData(0xe4f6, fontFamily: _duotone), // x
    0xe5ab: IconData(0xe5aa, fontFamily: _duotone), // snowflake
    0xe5df: IconData(0xe5de, fontFamily: _duotone), // arrow-square-out
    0xe607: IconData(0xe606, fontFamily: _duotone), // seal-check
    0xe617: IconData(0xe616, fontFamily: _duotone), // crown-simple
    0xe635: IconData(0xe634, fontFamily: _duotone), // infinity
    0xe67f: IconData(0xe67e, fontFamily: _duotone), // trophy
    0xe68f: IconData(0xe68e, fontFamily: _duotone), // users-three
    0xe6a3: IconData(0xe6a2, fontFamily: _duotone), // sparkle
    0xe6ef: IconData(0xe6ee, fontFamily: _duotone), // text-aa
    0xe6f7: IconData(0xe6f6, fontFamily: _duotone), // identification-badge
    0xe74f: IconData(0xe74e, fontFamily: _duotone), // brain
    0xe7b3: IconData(0xe7b2, fontFamily: _duotone), // calendar-dot
    0xe7b5: IconData(0xe7b4, fontFamily: _duotone), // calendar-dots
    0xe837: IconData(0xe836, fontFamily: _duotone), // images
    0xed63: IconData(0xed62, fontFamily: _duotone), // ranking
  };
}
