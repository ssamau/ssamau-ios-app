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
