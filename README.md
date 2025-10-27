# iOS App Template

SwiftUI starter app with sidebar navigation, Cognito Hosted UI login (Apple + Google), and manifest-driven configuration. Built to ship many branded apps off one codebase.

## Repo Layout

- `TemplateApp/` – Swift package for the app shell, auth flows, and API client.
  - `Config/` – theming, feature flags, and app metadata loaders.
  - `Auth/` – Hosted UI integrations, token storage, and session refresh.
  - `API/` – typed API client for platform backend routes.
  - `Resources/` – base assets to override per brand.
- `fastlane/` – automation for build, test, and TestFlight distribution.
- `.github/workflows/` – CI (unit tests, lint) + CD (TestFlight staging builds, manual prod promote).

## Status — 2025-10-26

- [x] Repository scaffolded with folder structure, README, and workflow placeholders.
- [x] Initialize SwiftUI project within `TemplateApp/` (blank home, sidebar skeleton).
- [x] Implement manifest-driven configuration loader.
- [x] Build Hosted UI auth flow (Apple + Google via Cognito) and session handling (token exchange stubbed, Hosted UI wiring ready).
- [ ] Add baseline tests and fastlane lanes for staging TestFlight uploads.
- [ ] Finalize reusable GitHub Actions workflow for branded repos.

## Build & Run

1. Run `bundle install` / fastlane setup (later) and regenerate the Xcode project when file structure changes:
   ```bash
   cd ios-app-template/TemplateApp
   ruby ../scripts/generate_project.rb
   ```
2. Open `TemplateApp/TemplateApp.xcodeproj` in Xcode 15.4+.
3. In the *Signing & Capabilities* tab, set your Apple development team (required for device builds).
4. Select the `TemplateApp` scheme and build for an iOS simulator (`⌘B`) or run on device.

## Testing Auth End-to-End

- Update `TemplateApp/TemplateApp/Config/app.json` with the real Cognito client ID, hosted UI domain, and custom URL scheme once the backend is deployed.
- The app uses `ASWebAuthenticationSession`; ensure your URL scheme is registered in Info.plist before testing on device.
- Tokens are cached in `UserDefaults` via `AuthSessionStorage`; swap in Keychain storage before production hardening.

## Handoff Notes

- Xcode 15.4+ required (compiled against iOS 17 SDK).
- Record any secrets required for CI (Apple API key, App Store Connect credentials) once workflows are wired.
- Keep staging API base URLs as defaults; note overrides if testing prod locally.
