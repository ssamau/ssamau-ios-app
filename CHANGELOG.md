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
