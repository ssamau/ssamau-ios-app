# Changelog

Cross-references the [web repo CHANGELOG](https://github.com/ssamau/ssamau-site/blob/main/CHANGELOG.md).
Entries that touch the API contract or i18n catalog should land in both repos in
the same sprint. See spec §17 for the process.

Format (per spec §17.7):

```
## [iOS] YYYY-MM-DD · short title
- summary bullet
- summary bullet
- **Web impact:** none / web should mirror X
```

For web entries:

```
## [Web] YYYY-MM-DD · short title
- edge fn / schema / i18n bullet
- **iOS impact:** none / iOS must update X
```

---

## [iOS] 2026-05-21 · Phase 1 — Signup-complete (token + PIN)

Spec §4 first-login flows for both invite paths.

- `SignupCompleteViewModel`: `Mode.token` / `.pin` switcher, validates
  passwords + NID-format + PIN-format locally (mirrors web's `su.err_*`
  messaging), calls `auth.signup.completeByToken` or
  `auth.signup.completeByPin`.
- `SignupCompleteView`: brand-aligned layout. Token field OR
  (national ID + PIN) fields by mode, password + confirm-password,
  submit button with progress state, mode-switch link, back link.
  Auto-dismisses 2s after a successful activation.
- `LoginView`: added "Activate account" link in the footer that pushes
  SignupCompleteView in PIN mode. Wrapped `onOpenURL` handler that
  routes `ssamau.com/signup.html?token=…` URLs to the same view
  with the token pre-filled and the mode set to `.token`.
- Universal Link end-to-end isn't live yet — Associated Domains
  entitlement requires a paid Apple Developer cert, and the AASA file
  needs hosting at `https://ssamau.com/.well-known/apple-app-site-association`.
  The `onOpenURL` handler is ready for both. Until then, members enter
  token or PIN manually via the LoginView link.
- **Web impact:** AASA file hosting is the only outstanding piece —
  coordinate via the web repo when the iOS cert is upgraded.

## [iOS] 2026-05-21 · Phase 1 — Profile photo + CV upload

- `Member` was storing `profile_photo_url` / `cv_url` as storage paths,
  not displayable URLs. Added `getMemberFile` calls on profile load to
  fetch fresh 1h signed URLs for both files.
- `ProfileViewModel`: `photoSignedURL`, `cvSignedURL`, `isUploading*`
  state, `uploadPhoto`, `uploadCV`, `deleteFile(kind:)` methods.
  Photo upload resizes via UIImage to fit within 512×512 then encodes
  as JPEG quality 0.85 so payloads stay well under the server's 3 MB
  cap. CV client-side guards 5 MB before POSTing.
- New "Files" section in ProfileView between About and Account. Two
  rows: Profile photo + CV. Each row shows the brand-specified hint
  ("JPG/PNG/WebP, 3 MB max" / "PDF only, 5 MB max"), an Upload
  button, a Delete button (only if a file exists), and for CV an
  Open button that opens the signed URL.
- PhotosPicker for image selection, .fileImporter for PDF. Both wired
  through ViewModel upload/delete actions; toast confirms success or
  failure.
- Avatar in header now uses `photoSignedURL` (was trying to render the
  raw storage path, which never worked).
- Square-crop UI for the avatar is deferred — current resize keeps
  aspect ratio. Spec §8.2 calls for crop-to-square; can layer on a
  cropper sheet later.
- **Web impact:** none.

## [iOS] 2026-05-21 · CertificatesViewModel → certs.listOwn

Web shipped certs.listOwn in api v126 (commit 9eb0af9). iOS now calls
the self-scoped action instead of certs.list with a member_id, which
was returning err.access.forbidden for regular members (ensureMemberScope
required admin/head scope). Same row shape — Certificate model unchanged.

**Web impact:** none — paired with the [Web] 2026-05-21 entry below.

## [Web] 2026-05-21 · certs.listOwn — member-scoped certificate list

- New action: returns the caller's own certificates joined with
  project_name. Auth-gated; empty array when user.member_id is null.
- certs.list unchanged — still admin/head only.
- **iOS impact:** CertificatesViewModel.load() now calls certs.listOwn
  with no params. Tab works for members without admin scope.

## [iOS] 2026-05-21 · Mirror web 2026-05-21 sync changes

Two web changes from the same day acknowledged on the iOS side.

**[Web] interest.submit blocks "any role" on full multi-role opps**
- Server now returns err.business.role_full when role_id=null on a
  fully-booked multi-role opportunity (previously slipped through
  silently with no slot to assign).
- iOS: pre-disable the "Any role" row in PickRoleSheet when every
  role in the opp is at capacity (`Opportunity.isFullCapacity`),
  with a red "All roles full" sub-label. The 409 path still works
  if a race condition fills the last slot mid-tap — APIClient
  surfaces err.business.role_full via the existing toast.

**[Web] pre-auth 401 envelope reaches the page**
- iOS APIClient already implements the same rule (commit 0205095):
  decode the envelope first regardless of status, surface err.* via
  the i18n catalog, only auto-logout when there's no decodable
  envelope OR the code is explicitly err.auth.unauthorized.
- No code change needed; documented for the sync contract.

## [iOS] 2026-05-21 · Brand identity reskin (cream theme + Almarai)

First full pass at the SSAM Brand Identity Guide aesthetic.

- Bundled Almarai TTFs (Light / Regular / Bold / ExtraBold) under
  `Resources/Fonts/`, registered via `UIAppFonts` in `SSAMAU/Info.plist`.
  Pulled from `google/fonts` github mirror at install time.
- New `Utils/Theme.swift` with typed font + color accessors:
  - `Font.ssDisplay`, `.ssH1`, `.ssH2`, `.ssBody`, `.ssBodyBold`,
    `.ssCaption`, `.ssTiny` — Almarai-based, mobile-adapted sizes
  - `Font.ssLatinItalic` — Georgia-Italic for the brand's secondary
    Latin subtitle pattern
  - `Font.ssLatinLabel` — system small-caps for tracked
    "T H E   B O A R D" style section headers
  - `Color.ssGreen / .ssGold / .ssCream / .ssPale / .ssCharcoal /
    .ssGrey / .ssLight` typed accessors
  - `GoldRule` view — the recurring 1.5pt gold hairline.
- Palette overhaul: Cream / Pale / Charcoal / Grey / Light added per
  brand swatches. The existing role aliases (Background, Ink, etc.)
  now resolve to the brand neutrals so light mode lands in the
  cream/charcoal/gold space the brand actually wants. Dark mode keeps
  the inverted relationship.
- LoginView reskinned: cream background, gold-bordered pale card, gold
  rule under the welcome message, brand fonts throughout, ssGreen
  primary CTA.
- ProfileView reskinned: cream background, gold-rule under member name,
  pale cards with thin gold borders, section headers use the
  Latin small-caps + Arabic H2 brand pattern ("S T U D Y &
  S P O N S O R S H I P / الدراسة والابتعاث"), brand fonts throughout.
- MemberTabView stubs: gold icon, ssH2 title, gold rule, on cream.
- RootView admin/head placeholders match the new visual language.

Heritage motifs (mihrab arch frame, eight-point star, crescent) +
proper sponsor/board card layouts are follow-ups when those screens land.

**Web impact:** none.

## [iOS] 2026-05-21 · Brand color hexes + keyboard fix + en.lproj move

- Localization layout: moved English strings from bundle root to
  `Resources/en.lproj/Localizable.strings`. Canonical Xcode layout —
  unambiguous when iOS resolves Arabic-preferred locale (which it
  appeared to be silently ignoring with the root-file layout).
- Debug print on `SSAMAUApp.init()` now logs `Bundle.main.localizations`,
  `preferredLocalizations`, current locale, and a sample lookup — Xcode
  console will say at-a-glance whether iOS is finding the right .lproj.
- LoginView keyboard avoidance: removed the `ZStack { Color... }` wrap
  that broke SwiftUI's auto-avoid behaviour. Background now sits on the
  ScrollView via `.background(...).ignoresSafeArea()`, content stays in
  safe area so the keyboard pushes the form up. Added a small
  `safeAreaInset` bottom buffer while a field is focused.
- Brand colors: BrandGreen #0F5A2D (was #1A5C2E), BrandGold #B4962D
  (was #B8932A), BrandGreenDark #093F1F — matches the
  `SSAM Brand Identity Guide.pdf`. Dark-mode variants slightly
  brightened for contrast.
- **Web impact:** none.
- **Followup:** the brand guide also specifies Almarai (Arabic) +
  Georgia (Latin) fonts and a cream-and-green light theme. This commit
  only addresses the palette — full brand reskin is its own task.

## [iOS] 2026-05-21 · Localization: register Arabic + in-app Settings link

- Bug: device locale set to Arabic gave RTL layout (SwiftUI detected
  it correctly) but kept English strings — and iOS Settings showed no
  per-app Language picker for SSAMAU.
- Root cause: Xcode 16's auto-generated Info.plist did not include
  `CFBundleLocalizations` for synchronized-folder projects with .lproj
  subdirectories. Without that key, iOS only considers the development
  region (en) supported regardless of bundled `ar.lproj/Localizable.strings`.
- Fix: minimal `SSAMAU/Info.plist` with `CFBundleLocalizations = [en, ar]`,
  wired via `INFOPLIST_FILE = Info.plist`. Kept outside the synchronized
  `SSAMAU/` source folder to avoid "Multiple commands produce" conflict.
  Auto-generated keys (scene manifest, icons, orientations) still merge
  in from `INFOPLIST_KEY_*` settings.
- Verified: `plutil -extract CFBundleLocalizations` returns `["en","ar"]`
  in the built bundle.
- Added "Change language" buttons on both LoginView (footer) and
  ProfileView (above sign-out) that open
  `UIApplication.openSettingsURLString` — iOS Settings → SSAMAU page,
  where the language picker now appears.
- **Web impact:** none.

## [iOS] 2026-05-21 · Phase 1 — Profile enum labels + edit mode

- `Utils/MemberFieldMaps`: ports the enum-key → label maps from the web's
  `member/tabs/profile.js` (scholarship, university, study level, study
  start, graduation). Resolves `apply.s3.opt.*` / `apply.s4.opt.*` via
  NSLocalizedString; falls back to raw value if a server-side enum is
  ahead of the iOS map. Also DOB formatter (ISO → locale medium) and
  server-format parser for DatePicker.
- `Member`: editable fields are now `var` so the draft can be mutated
  in-place during editing.
- `ProfileViewModel`: `draft: Member?` mirror for in-flight edits,
  `startEditing` / `cancelEditing` / `save` actions. Save calls
  `members.updateOwn` with a `{ data: { ... } }` payload of all
  editable fields (server uses COALESCE on nulls). Toast on success/fail.
- `ProfileView`: top-bar Edit / Save / Cancel buttons. Editable rows
  swap labels for TextField / DatePicker / Menu-picker depending on
  field type. Read-only rows use the new enum labels and the formatted
  DOB.
- ios-only-strings: `common.edit`, `common.save`, `common.cancel`.
- Photo + CV upload still deferred to the next commit.
- **Web impact:** none.

## [iOS] 2026-05-21 · Phase 1 — ProfileView (read-only) + MemberTabView

- `Models/Member`: Codable mirror of `members.getOwn` response, covers
  the full self-update whitelist + joined `committee_name`.
- `ViewModels/ProfileViewModel`: loads via `members.getOwn`, pull-to-refresh.
- `Views/Member/ProfileView`: avatar + chips header, hours/status stat
  cards, four sections (Personal / Study / About / Account), `ro_note`
  helper, sign-out button.
- `Views/Member/MemberTabView`: 5-tab bar (Opportunities, Tasks, Hours,
  Certificates, Profile) — 4 are stubs until Phase 2; Profile is real.
- `RootView` routes the member role → `MemberTabView`.
- `scripts/strings-to-localizable.mjs` now merges
  `scripts/ios-only-strings.json` on top of the web catalog so iOS-only
  keys (tab labels, etc.) survive future regenerations. 10 keys added.
- Editing, photo upload, CV upload deferred to the next Phase 1 commit.
- **Web impact:** none.

## [iOS] 2026-05-21 · Phase 1 — AuthService + LoginView

- `Services/AuthService`: three-path login (resolveIdentifier → supabase | legacy).
  Stores token in Keychain via `SessionStore.login`.
- `Models/AuthDTOs`: response shapes for `auth.resolveIdentifier`,
  `auth.exchangeSupabaseToken`, and the Supabase Auth REST endpoint.
- `ViewModels/LoginViewModel`: identifier+password state, loading flag,
  localized error surface.
- `Views/Auth/LoginView`: spec §8.1 — logo, identifier field, password field
  with show/hide toggle, sign-in button, forgot-password placeholder.
- `RootView` now renders `LoginView()` in the `.loggedOut` case.
- **Web impact:** none — depends on the [Web] 2026-05-21 token-in-body fix
  below (already deployed v124).

## [Web] 2026-05-21 · auth.exchangeSupabaseToken returns token in body

- Edge fn: handler now returns `{ token, user }` symmetric with legacy `auth`.
  Web unchanged (still reads cookie via Set-Cookie).
- **iOS impact:** unblocks Supabase-path login; `AuthService.loginSupabase`
  reads `data.token` and hands it to `SessionStore.login`.

## [iOS] 2026-05-21 · Phase 0 scaffold

- New repo, Xcode project, hygiene files (`.gitignore`, `README`, this `CHANGELOG`).
- iOS deployment target set to 16.0, Swift 5.9, bundle ID `com.ssamau.app`.
- `APIClient`, `KeychainService`, `SessionStore`, `ErrorLocalization` foundation.
- Brand color tokens + en/ar Localizable.strings (1642 keys).
- AppIcon + SSAMLogo image set + brand-green AccentColor.
- **Web impact:** none.
