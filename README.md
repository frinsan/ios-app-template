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
- [ ] Initialize SwiftUI project within `TemplateApp/` (blank home, sidebar skeleton).
- [ ] Implement manifest-driven configuration loader.
- [ ] Build Hosted UI auth flow (Apple + Google via Cognito) and session handling.
- [ ] Add baseline tests and fastlane lanes for staging TestFlight uploads.
- [ ] Finalize reusable GitHub Actions workflow for branded repos.

## Handoff Notes

- When the Xcode project is added, document the minimum required Xcode version here.
- Record any secrets required for CI (Apple API key, App Store Connect credentials) once workflows are wired.
- Keep staging API base URLs as defaults; note overrides if testing prod locally.
