# Privacy policy page polish — design

Date: 2026-10-08  
Scope: `docs/privacy/index.html` (GitHub Pages; loaded by in-app WebView via `AppUrls.privacyPolicy`)

## Goal

Improve the public privacy policy page with clearer wording and light visual polish. Keep every policy fact the same. Remove the Android package ID from the page.

## Decisions

| Topic | Choice |
| --- | --- |
| Scope | Content wording + visual polish |
| Package ID (`com.winklo.faseencm`) | Remove entirely (not required by Play; currently shown at top) |
| Policy substance | Unchanged — same services, data types, deletion flow, contact path |
| Visual direction | Clean document on existing dark Winklo tokens |
| App / Flutter code | Out of scope (URL and WebView stay as-is) |

## Content

- Brand line at top: `Winklo` only (no package id).
- Title: `Privacy Policy`.
- Update “Last updated” to the ship date of this change.
- Keep the short-version callout; tighten wording only.
- Keep section order:
  1. Intro
  2. Short version
  3. Information stored on your device
  4. Account and profile
  5. Gameplay scores
  6. Other network processing
  7. What we do not collect
  8. Children
  9. Your choices and account deletion
  10. Contact
- Contact remains GitHub issues only.
- Do not add package ID mid-page or elsewhere.

## Visual

Reuse CSS variables: `--ink`, `--on-ink`, `--muted`, `--ember`, `--wall`.

- Stronger `h1` hierarchy; clearer `h2` spacing.
- Subtle ember accent on section headings (underline or left border).
- Short-version card: left ember border, calm padding; keep rounded wall background.
- Ember links; high-contrast body text.
- Max-width ~42rem; comfortable mobile padding.
- System UI font stack only (no new webfonts on this page).

## Non-goals

- Changing Data Safety form text in Play Console
- New contact email, in-app account delete, or other product changes
- Landing-page / marketing styling
- Edits to Flutter profile WebView

## Success criteria

- Page reads clearly on mobile and desktop.
- Package ID is not shown anywhere.
- A reader familiar with the old policy would recognize the same facts.
- `docs/privacy/index.html` remains a single self-contained HTML file suitable for GitHub Pages.
