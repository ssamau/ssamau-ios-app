# SSAMAU iOS

Native iOS client for the SSAM (Saudi Students Association in Melbourne) platform.
SwiftUI · iOS 16+ · MVVM. Talks to the same Supabase Edge Function the web app
at [ssamau.com](https://ssamau.com) uses.

Status: pre-MVP, Phase 0 (foundation).

## Repos

- **iOS (this repo):** [ssamau/ssamau-ios-app](https://github.com/ssamau/ssamau-ios-app)
- **Web platform:** [ssamau/ssamau-site](https://github.com/ssamau/ssamau-site) — canonical source of truth for business rules, schema, and the API

## Stack

| Layer | Choice |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Architecture | MVVM + `@Observable` |
| Networking | `URLSession` + async/await |
| Encoding | `Codable` |
| Secure storage | Keychain |
| Localization | `Localizable.strings` (en + ar, RTL) |
| Min iOS | 16.0 |

## Backend

Single Supabase Edge Function endpoint, action-dispatched:

```
POST https://pfibxvwiulwiiuwerawe.supabase.co/functions/v1/api
Headers:
  Authorization: Bearer <HS256-token-from-Keychain>
  apikey: <SUPABASE_ANON_KEY>
  Content-Type: application/json
Body: { "action": "<name>", ...params }
```

Response envelope: `{ success, data?, error?, errorParams? }`.

The web app uses cookies; iOS uses Bearer headers — same dispatcher, different
transport. See `Services/APIClient.swift`.

## Layout

```
SSAMAU.xcodeproj           # nested at SSAMAU/SSAMAU.xcodeproj
SSAMAU/SSAMAU/             # Swift sources
  ├── SSAMAUApp.swift
  ├── Resources/           # Localizable.strings (en + ar)
  ├── Models/              # Codable structs
  ├── Services/            # APIClient, AuthService, KeychainService, SessionStore, CacheService
  ├── Views/{Auth,Member,Head,Admin,Common,Verify}/
  ├── ViewModels/
  └── Utils/
```

## Working with the spec

The full ~45-page iOS requirements PDF lives at
`~/Desktop/SSAM-Demo-Output/pdfs/ios-app-requirements.pdf` (not in this repo —
it's a planning artifact, not shipping content). Refer to it for screen-level
behaviour and API contract details.

## Keeping web + iOS in sync

See `CHANGELOG.md` for the cross-repo change log. Every web entry that affects
iOS gets an explicit `**iOS impact:**` line. Process is documented in spec §17.
