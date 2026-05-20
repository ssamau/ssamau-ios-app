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

## [iOS] 2026-05-21 · Phase 0 scaffold

- New repo, Xcode project, hygiene files (`.gitignore`, `README`, this `CHANGELOG`).
- iOS deployment target set to 16.0, Swift 5.9, bundle ID `com.ssamau.app`.
- **Web impact:** none.
