# Winklo — Play Store media prompts

Prompts and production plan for the Play Store **screenshots** and **promo video**.

Winklo ships **three daily games**:

| Game | What you do | Accent |
|---|---|---|
| **Zip** | Draw one line through numbered cells 1 → N and fill every cell | Ember `#FF6B2C` |
| **Path Words** | Trace hidden words across a letter grid | Sky `#38BDF8` |
| **Sudoku** | Classic 9×9 Sudoku, clean and calm | Teal `#2DD4BF` |

Shared hooks: a new puzzle every day, daily streaks 🔥, a daily leaderboard with **No hint** / **No mistakes** clean-run chips, beat-your-best-time, and pause anytime (your run is saved).

Do not mention Word Match or Category Race anywhere in store media.

---

## Contents

1. [Brand kit](#1-brand-kit)
2. [Play Store specs & policy](#2-play-store-specs--policy)
3. [Screenshots](#3-screenshots)
4. [Promo video](#4-promo-video)
5. [Feature graphic](#5-feature-graphic)
6. [Pre-upload checklist](#6-pre-upload-checklist)

---

## 1. Brand kit

Source of truth: `lib/core/theme/app_theme.dart`.

| Token | Hex | Use |
|---|---|---|
| Ink | `#0F172A` | Background |
| On ink | `#F8FAFC` | Headlines |
| Ink soft | `#94A3B8` | Sublines |
| Ember | `#FF6B2C` → `#E85A1C` | Hero color, Zip, brand |
| Sky | `#38BDF8` → `#0284C7` | Path Words |
| Teal | `#2DD4BF` / `#34D399` → `#059669` | Sudoku, success |
| Rose | `#FB7185` | Zip numbers, highlights |
| Amber | `#FBBF24` | Leaderboard / trophy |

- **Font:** Lexend (ExtraBold 800 for headlines, Medium for sublines).
- **Logo:** zig-zag ember line connecting 6 dots on a rounded dark tile (`fastlane/metadata/android/en-US/images/icon.png`).
- **Tagline:** "Quick solo mini-games."
- **Marketing line:** "The smartest minute of your day."

---

## 2. Play Store specs & policy

| Asset | Spec |
|---|---|
| Phone screenshots | 2–8 images, PNG/JPEG, ≤ 8 MB, each side 320–3840 px, long side ≤ 2× short side. **Use 1080 × 1920.** |
| Promo video | YouTube URL, Public or Unlisted, **ads off**, not age-restricted. Landscape 1920 × 1080 recommended, ~30 s. |
| Feature graphic | 1024 × 500 PNG/JPEG. Doubles as the video thumbnail. |

**Policy:** no "#1", "Best", "Top", "Free", "New", ratings, prices, awards, or store badges in any image or video text.

Output folder for finished screenshots: `fastlane/metadata/android/en-US/images/phoneScreenshots/` (named `01-…png`, `02-…png` so upload order is right).

---

## 3. Screenshots

### Strategy

- **Sell a feeling, not a feature.** Each slide is built around one emotion: satisfaction, discovery, calm, streak FOMO, competition.
- **Game pieces are 3D hero objects** (glowing path, glass letter tiles, glass Sudoku cells) bursting out of the phone, not flat UI.
- **Panorama continuity:** one glowing ember line runs through all slides, leaving the right edge of each and entering the next, so people keep swiping.
- **Slides 1–3 do 80% of the work.** Most users never swipe past them.

### Workflow

1. Generate slides 1 and 2 with the master prompt.
2. Reuse them as style references for the rest: *"Match the style of the attached images exactly."*
3. Check every letter and number the AI renders. Fix errors in Figma/Photoshop or regenerate.
4. Export at 1080 × 1920.

### 3.1 Master prompt (send first)

```
You are a world-class mobile game marketing art director who has produced Play
Store screenshot sets for top puzzle games (in the spirit of NYT Games, Wordle,
LinkedIn Zip/Queens, Monument Valley). Create a set of 6 Google Play phone
screenshots for "Winklo" that make a scrolling user stop, feel something, and
tap Install.

THE APP
Winklo is three beautiful daily puzzle games, about one minute each:
- ZIP: draw one continuous glowing line through numbered dots 1→N and fill every
  cell of the grid. Signature look: a neon ember-to-pink gradient path.
- PATH WORDS: trace hidden words through a letter grid; each found word lights up
  in its own jewel color (sapphire, emerald, amber, ruby).
- SUDOKU: a calm, clean, modern 9×9 Sudoku with soft teal highlights.
New puzzles every day, daily streaks 🔥, a daily leaderboard with "No hint" and
"No mistakes" badges, beat-your-best-time, pause anytime.

THE EMOTION WE SELL
"The smartest minute of your day." Instant satisfaction, calm focus, a small
daily win, and the pull of not wanting to break the streak. The viewer should
think: "That looks so satisfying. I want to try today's puzzle."

VISUAL DIRECTION
- Premium dark world: deep midnight ink #0F172A to #111827, atmospheric depth
  (soft volumetric glow, bokeh, faint floating grid particles).
- Hero color is Ember #FF6B2C, glowing like neon or molten light. Supporting
  colors: Sky #38BDF8 (Path Words), Teal #2DD4BF (Sudoku), Rose #FB7185,
  Amber #FBBF24.
- Game elements are HERO 3D OBJECTS, not flat UI: a thick glowing neon path,
  glossy rounded glass letter tiles, translucent glass Sudoku cells, a
  flame-shaped streak badge. Material: soft glass and glowing acrylic, cinematic
  rim light.
- A phone is optional per slide. When present, it is a modern Android device at
  a dynamic 10–20° angle, with game elements bursting OUT of the screen.
- CONTINUITY: one glowing ember line runs across ALL 6 slides, exiting the right
  edge of each slide and entering the left edge of the next, forming one
  continuous panorama.
- Typography: Lexend ExtraBold, huge (headline ~9% of canvas height), white
  #F8FAFC, with ONE word per headline glowing in the slide's accent color.
  Sublines in Lexend Medium #94A3B8. Max 5 words per headline.

HARD RULES
- Canvas 1080 × 1920 px, 9:16, 60 px safe margins.
- Spell all text exactly as given. Do not add any other words.
- Puzzles must look plausible: numbers in sequence, real English words on tiles,
  no repeated digits in any Sudoku row, column or 3×3 box, no gibberish.
- Never write "#1", "Best", "Free", "Top", ratings, prices, awards, or store
  badges.
- One idea, one focal point, generous negative space per slide.
- Only these three games exist: Zip, Path Words, Sudoku. Show no other games.

Confirm the direction, then generate the slides one at a time as I send them.
```

### 3.2 Slide prompts

**Slide 1 — The hook (Ember)**
```
Slide 1. Headline: "The smartest minute of your day" (glow "minute", ember).
Scene: a phone floating at a tilt. A thick neon ember-to-pink path bursts out of
the screen in one confident zig-zag stroke (echoing the Winklo logo: six dots
joined by a zig-zag line), passes through glowing number orbs 1→6 and sweeps off
the right edge. Small Winklo logo + "Winklo" wordmark at the bottom.
Mood: wow, satisfying, premium.
```

**Slide 2 — Zip: satisfaction (Ember)**
```
Slide 2. Headline: "One line. Every cell." (glow "One line", ember).
Subline: "Feel the click when it fills."
Scene: a large 3D 6×6 glass puzzle board at an isometric angle. A glowing path
has just filled the final cell. A burst of ember sparks and a soft shockwave
ripple from the last number orb. The continuous ember line enters from the left
and becomes the path.
```

**Slide 3 — Path Words: discovery (Sky)**
```
Slide 3. Headline: "Find the hidden words" (glow "hidden", sky blue).
Subline: "A fresh grid every morning."
Scene: glossy 3D glass letter tiles floating in a loose 5×5 grid. Tiles spelling
FACE glow sapphire, DOCK glows emerald, INCH glows amber; the remaining tiles
are dim smoky glass. A trail of light (the ember line, turning sky blue) connects
the letters of the word being traced. Gentle depth of field.
```

**Slide 4 — Sudoku: calm focus (Teal)**
```
Slide 4. Headline: "Sudoku, beautifully calm" (glow "calm", teal).
Subline: "Clean grid. Play at your pace."
Scene: a 9×9 Sudoku board of translucent glass cells floating at a gentle
isometric angle, with soft teal light glowing from beneath. Only a sparse set of
digits is shown (about 25, valid: no repeats in any row, column or 3×3 box).
One digit "7" lifts out of the board, glowing teal, about to drop into its
cell. The ember line glides along the board's outer edge. Serene, spa-like
mood, lots of breathing room.
```

**Slide 5 — Streak: FOMO (Ember)**
```
Slide 5. Headline: "Don't break the streak" (glow "streak", ember).
Subline: "Three new puzzles. Every day."
Scene: a large glowing 3D flame-shaped badge reading "🔥 30" floats center like
a trophy. Around it, three small glass cards orbit: an ember Zip path, sky
letter tiles, a teal Sudoku grid, each with a glowing check mark. A ring of 7
day-dots below is fully lit ember. The ember line wraps around the badge.
```

**Slide 6 — Leaderboard + CTA (Amber)**
```
Slide 6. Headline: "Beat your best time" (glow "best", amber).
Subline: "Go for No hint. No mistakes."
Scene: a glowing glass stopwatch reading "0:42" with motion streaks rises above
a three-step glass podium (ember, sky, teal steps). Two glowing pill badges float
beside it, reading "No hint" and "No mistakes". Soft confetti drifts. The ember
line ends here by tracing the Winklo logo shape above the stopwatch.
Winklo wordmark at the bottom.
```

### 3.3 Headline variants for A/B tests

Run these in **Play Console → Store listing experiments**, testing slide 1 only.

| Tone | Slide 1 headline |
|---|---|
| Calm / mindful (default) | The smartest minute of your day |
| Playful | Three puzzles. One coffee. |
| Competitive | Can you solve today's in a minute? |
| Habit | Your new daily ritual |

---

## 4. Promo video

### Strategy

- **Hybrid:** AI-generated cinematic shots + **real gameplay recordings**. AI video cannot keep numbers and letters stable between frames, so it must never be used for real gameplay.
- **The first 3 seconds** show the most satisfying moment, not a logo.
- **Plan for no sound:** every message is on-screen text. Sound effects are a bonus.
- AI models make clips of about 5–10 seconds. Generate each shot separately with the same style bible, then edit them together.

### 4.1 Record real gameplay

Use a phone with Developer Options on, Do Not Disturb on, and a high streak and a clean status bar staged.

```bash
adb shell screenrecord --size 1080x2160 --bit-rate 12000000 /sdcard/zip.mp4
# play, then Ctrl+C
adb pull /sdcard/zip.mp4
```

Clips to capture (rehearse until each solve looks fast and confident):

| File | Content |
|---|---|
| `home.mp4` | Home screen with a high streak; tap **Play today's Zip** |
| `zip.mp4` | A fast Zip solve ending with the final cell filling + completion screen |
| `path-words.mp4` | 2–3 words lighting up in a row + completion |
| `sudoku.mp4` | Several confident digit entries + the board completing |
| `leaderboard.mp4` | Daily leaderboard scroll showing **No hint** / **No mistakes** chips |

### 4.2 Style bible (paste at the start of EVERY AI shot prompt)

```
STYLE: premium cinematic 3D motion design, dark midnight ink background (#0F172A),
glowing neon ember-orange (#FF6B2C) to pink gradient light trails, glossy glass
and acrylic game pieces, soft volumetric glow, shallow depth of field, floating
dust particles, smooth slow camera moves, satisfying ASMR-like motion, 4K, 16:9.
Accents: sky blue #38BDF8, teal #2DD4BF, amber #FBBF24. No text, no logos, no
human faces, no gibberish letters, no extra UI.
```

On-screen text is added in the editor, never generated. AI text flickers and gets misspelled.

### 4.3 Storyboard (30 s, 16:9)

| Time | Shot | Source | On-screen text |
|---|---|---|---|
| 0–3s | **Hook:** glowing ember line snakes through orbs 1→8, snaps into the last one in a spark burst | AI (V1) | — |
| 3–6s | Phone flies in; Zip solve plays on its screen | AI (V2) + `zip.mp4` | **One line. Every cell.** |
| 6–9s | Zip recording full-frame, ending on the completion | `zip.mp4` | **Feel the click.** |
| 9–12s | Floating glass letter tiles; words light up sapphire → emerald | AI (V3) | **Find the hidden words** |
| 12–15s | Path Words recording | `path-words.mp4` | |
| 15–18s | Glass Sudoku board; a teal digit drops into place, a row glows | AI (V4) | **Sudoku, beautifully calm** |
| 18–21s | Sudoku recording completing | `sudoku.mp4` | |
| 21–24s | Flame streak badge counts up 1 → 30 and ignites, three game cards orbit | AI (V5) | **3 puzzles. Every day. 🔥** |
| 24–27s | Leaderboard recording with clean-run chips; stopwatch + podium overlay | `leaderboard.mp4` + AI (V6) | **No hint. No mistakes.** |
| 27–30s | Ember line traces the Winklo logo; wordmark fades in | AI (V7) + logo PNG | **Winklo — Today's puzzle is waiting** |

### 4.4 AI shot prompts (style bible + one of these)

**V1 — Hook**
```
Extreme close-up macro shot. A thick glowing neon line, ember-orange fading to hot
pink, draws itself through a dark glass grid, smoothly connecting floating
numbered glass orbs in order with sharp 90-degree turns. When it reaches the
final orb, the orb flashes white-hot and releases a burst of sparks and a soft
circular shockwave. Camera slowly pushes in. 3 seconds.
```

**V2 — Phone fly-in**
```
A sleek modern black Android phone with a blank glowing screen spins slowly into
frame from the lower right and settles at a 15-degree tilt, center frame. A neon
ember light trail wraps around it as it lands. Dark ink background, soft orange
rim light. 3 seconds.
```
→ In the editor, place `zip.mp4` onto the blank screen with corner-pin / screen replace.

**V3 — Path Words tiles**
```
Glossy rounded square glass letter tiles float in a loose 5×5 grid in dark space,
gently bobbing. A trail of light connects tiles in sequence and they light up
sapphire blue, then a second group lights up emerald green. Unlit tiles stay
smoky glass. Slow orbit camera, shallow depth of field. 3 seconds.
```
→ Keep tile faces blank or blurred in the AI shot, and add letters in post if needed.

**V4 — Sudoku calm**
```
A 9×9 board of translucent glass cells floats at a gentle isometric angle over
dark space, lit softly from beneath in teal. A single glowing teal glass cube
descends slowly and settles into an empty cell with a soft ripple of light; then
the whole row glows teal for a moment and fades. Serene, slow, spa-like. Cells
are blank (no digits). 3 seconds.
```
→ Cells are left blank on purpose. Overlay real digits in post or cut quickly to `sudoku.mp4`.

**V5 — Streak**
```
A large 3D glass flame-shaped badge floats center frame. Three small glass cards
orbit it: one with a glowing orange line path, one with blue glass tiles, one with
a teal grid. A ring of seven small dots beneath ignites one by one in ember orange,
then the flame inside the badge bursts to life with fire-like glow and embers
drifting upward. Hero lighting, slow push-in. 3 seconds.
```

**V6 — Competition**
```
A glowing glass stopwatch with motion streaks rises upward while a three-step glass
podium (ember orange, sky blue, teal) assembles beneath it. Soft confetti drifts
down. Triumphant but calm. 3 seconds.
```

**V7 — End card background**
```
A single glowing ember-orange line traces a zig-zag path connecting six glowing
dots in empty dark space (horizontal, then down-right diagonal, down-left
diagonal, down-right, then up-right). It settles, glows softly and pulses once.
Plenty of empty space on the right. 3 seconds.
```
→ Overlay the real logo PNG as the line finishes. The AI shape will not match the logo exactly.

### 4.5 Edit

- **Tool:** CapCut (free, quick) or DaVinci Resolve (free, more control).
- **Text:** Lexend ExtraBold, white, key word in the shot's accent color. Pop-in scale animation (~0.15 s). Keep text clear of on-screen gameplay.
- **Music:** upbeat minimal lo-fi / electronic, 110–120 BPM, royalty-free (YouTube Audio Library, Pixabay). Cut on the beat.
- **Sound effects:** soft pluck per Zip cell, glassy tick per letter, gentle chime on every completion, whoosh on the phone fly-in.
- **Export:** 1920 × 1080, H.264, 30 fps. Also export a 9:16 cut for YouTube Shorts / Reels / ads.
- **Upload:** YouTube (Unlisted, ads off) → paste the URL in Play Console → Main store listing → Video.

### 4.6 Tools

Image-to-video gives the most consistent results: generate a still in the screenshot style, then animate it. Options: Kling, Runway Gen-4, Google Veo, Higgsfield.

---

## 5. Feature graphic

The feature graphic is also the video thumbnail, so it needs to match the new style.

```
Design a Google Play feature graphic, exactly 1024 × 500 px, for "Winklo".
Dark midnight ink background #0F172A with soft volumetric glow. On the left, the
Winklo wordmark in Lexend ExtraBold white with the subline "The smartest minute
of your day" in #94A3B8. On the right, three floating 3D glass game objects in a
loose arc: a glowing ember-orange zig-zag path through number orbs (Zip), glossy
glass letter tiles glowing sky blue (Path Words), and a small translucent teal
glass Sudoku grid. A single ember light trail connects all three. Keep the center
clear of important detail (Play overlays a play button there when a video is set).
No other text, no badges.
```

---

## 6. Pre-upload checklist

- [ ] Only Zip, Path Words and Sudoku appear. No Word Match or Category Race anywhere.
- [ ] Every rendered word is spelled correctly; every Sudoku digit is valid.
- [ ] No banned claims ("#1", "Best", "Free", ratings, prices, badges).
- [ ] Screenshots are 1080 × 1920, ≤ 8 MB, named `01-…` to `06-…`.
- [ ] Old `phoneScreenshots/*.png` replaced. The lime-green edge in the old `02-zip.png` / `03-path-words.png` is gone.
- [ ] Video on YouTube, Public or Unlisted, ads off, not age-restricted.
- [ ] `short_description.txt` and `full_description.txt` updated to list the three games (they still mention Word Match and Category Race).
- [ ] Feature graphic regenerated to match the new style.
