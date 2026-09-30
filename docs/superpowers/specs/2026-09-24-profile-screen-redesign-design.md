# Profile screen redesign — design

Date: 2026-09-24  
Status: approved for implementation

## Goal

Polish the signed-in Profile tab into an identity hero + settings list. Move display-name editing into a bottom sheet. Add Privacy policy (in-app WebView), About the game (dialog), Report an issue (form → Firestore with user details), and Log out. Cover analytics and tests.

## Product decisions

| Topic | Choice |
|-------|--------|
| Scope | Visual polish of signed-in profile + new list actions (not a stats hub) |
| Name edit | Bottom sheet (field + Save); not inline on the main screen |
| Avatar edit | Unchanged — tap avatar → existing `AvatarEditSheet` |
| Signed-out | Unchanged — `BlurredMockEmptyBody` + sign-in CTA; no settings list |
| About | Dialog: short blurb + app version + Got it |
| Privacy URL | `https://muhammedfaseencm.github.io/winklo/privacy/` |
| Report label | **Report an issue** |
| Report UI | Dedicated screen: title + description → Firestore |
| Report auth | Signed-in only (list rows only appear when signed in) |
| Log out | Immediate `AuthCubit.signOut()`; no confirm dialog |

## Signed-in layout

```
Profile AppBar
  Avatar (tap → avatar sheet)
  Display name (tap / edit affordance → name sheet)
  Grouped list:
    Privacy policy ›
    About the game ›
    Report an issue ›
    ────────
    Log out
```

Visual language: ink/ember, Lexend, wall-colored grouped tiles, ember accents — aligned with Home. No inline name field or Save on the main screen.

### Name edit sheet

- Reuses `ProfileCubit` (set draft / save / name validation errors).
- Same validation as today (non-empty, ≤ 24 chars).
- On success: close sheet; name on profile updates via cubit state.
- On failure: show error in sheet; keep open.

### Signed-out mock

- Keep blur tease. Update `ProfileSignedOutMock` only if needed so the decorative mock still resembles the new signed-in layout (hero + inert list), without interactive rows.

## Destinations

### Privacy policy — `/profile/privacy`

- Full-screen route with AppBar title from `AppStrings`.
- In-app WebView (`webview_flutter`) loading the Pages privacy URL.
- Loading indicator while the page loads; basic error + retry if load fails.
- **Child route of the profile shell branch** so back returns to Profile; bottom nav may remain visible.

### About the game

- `showDialog` (or equivalent light modal), not a route.
- Copy: short product blurb about daily Zip / Path Words, leaderboard, streak.
- Show app version from `package_info_plus` (e.g. `v1.2.3`).
- Primary dismiss: Got it.

### Report an issue — `/profile/report`

- AppBar: Report an issue.
- Form: Title (required, max 80), Description (required, max 2000).
- Send button; disabled while submitting / when invalid.
- Success: snackbar + pop to Profile.
- Failure: snackbar or inline error; stay on screen.

### Log out

- List tile at bottom of the group (quieter / destructive styling).
- Calls existing `AuthCubit.signOut()`.

## Data — Firestore `issue_reports/{reportId}`

Auto-ID documents. Client create only.

| Field | Type | Source |
|-------|------|--------|
| `title` | string | Form |
| `description` | string | Form |
| `uid` | string | Auth |
| `displayName` | string | Profile / Auth |
| `photoUrl` | string \| null | Profile |
| `avatarId` | string \| null | Profile |
| `appVersion` | string | `package_info_plus` |
| `buildNumber` | string | `package_info_plus` |
| `platform` | string | `ios` / `android` / etc. |
| `createdAt` | timestamp | Server timestamp |

### Security rules

- `create`: signed-in; `request.auth.uid == request.resource.data.uid`; validate key set, string lengths, and types.
- `read` / `update` / `delete`: deny from clients.

Document rules + indexes (if any) under `firestore/`. Update `FIREBASE.md` with the collection note.

## Architecture

Feature-first, domain/data split:

| Layer | Pieces |
|-------|--------|
| Domain | `IssueReport` (or submit params value type), `IssueReportRepository`, `SubmitIssueReport` usecase |
| Data | `IssueReportRepositoryImpl` (Firestore) |
| DI | Register repo + usecase in `app_repositories` |
| UI | Profile list widgets; `NameEditSheet`; `PrivacyWebViewScreen`; `ReportIssueScreen` + `ReportIssueCubit` |
| Shared | Extend `AnalyticsRepository` + Firebase impl; AppStrings for all copy |

Name editing stays on existing `ProfileCubit`. Report flow gets its own cubit so profile state stays focused.

### Routing

- Add child routes under the profile `StatefulShellBranch`:
  - `/profile/privacy`
  - `/profile/report`
- Screen views continue via `AnalyticsRouteObserver`.

### Dependencies

- Add `webview_flutter` for privacy.
- Reuse existing `package_info_plus` for About + report metadata.

## Analytics

All events go through `AnalyticsRepository` → `FirebaseAnalyticsRepositoryImpl` (no direct Firebase Analytics in UI).

| Event | When |
|-------|------|
| `profile_privacy_opened` | Privacy row tapped / screen opened |
| `profile_about_opened` | About dialog opened |
| `profile_report_opened` | Report screen opened |
| `profile_report_submitted` | Report create succeeded |
| `profile_sign_out` | Log out tapped |

Do not log title/description contents. Screen views for privacy/report rely on the route observer where possible; product events above are explicit.

## Testing

| Area | Coverage |
|------|----------|
| `SubmitIssueReport` / repo | Success, failure; payload includes user + app metadata |
| `ReportIssueCubit` | Validation, submitting, success, failure (`bloc_test` + `mocktail`) |
| Profile widget | Signed-in list shows four rows; name sheet opens; signed-out unchanged |
| Report widget | Can enter title/description and trigger submit (mocked usecase) |
| Analytics | Verify profile events called with mocks |
| Firestore rules | Create OK for owner with valid shape; reject unsigned, wrong uid, oversized strings |

Prefer analyzing/testing changed files; follow existing profile/home test patterns.

## Out of scope

- Streak / best-time stats on Profile
- Confirm dialog before sign-out
- Admin UI to read reports
- Changing privacy policy content (URL only)
- Email / category fields on the report form

## Success criteria

1. Signed-in Profile reads as identity hero + settings list; name edits only via sheet.
2. Privacy opens in-app WebView at the Pages URL.
3. About shows blurb + version.
4. Report submits to Firestore with form text **and** user/app metadata; rules enforce create-only.
5. Analytics events fire for privacy / about / report open / report submit / sign out.
6. Tests cover cubit, submit path, key widgets, and rules.
