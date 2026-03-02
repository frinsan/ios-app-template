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

## Welcome Screen Preview

- `TemplateApp/TemplateApp/WelcomeView.swift` renders the Grok-style intro screen with the looping `neuron_loop.mp4` background bundled in the repo.
- It appears only when `AuthState` is `.signedOut`. Tapping **Skip** dismisses it for the current session (not persisted) while Apple/Google/email buttons call the same Hosted UI + email flows already used by `LoginView`.
- The small placeholder line above the main title uses the manifest’s `displayName` (or a fallback) so each branded app can supply its own subtitle. Update the static strings in this file when you brand a new app.

## Status — 2025-10-26

- [x] Repository scaffolded with folder structure, README, and workflow placeholders.
- [x] Initialize SwiftUI project within `TemplateApp/` (blank home, sidebar skeleton).
- [x] Implement manifest-driven configuration loader.
- [x] Build Hosted UI auth flow (Apple + Google via Cognito) and session handling.
- [x] Add native email sign-up/login flow backed by `/v1/auth/email/{signup,login}`.
- [x] Add baseline tests and fastlane lanes for staging TestFlight uploads. (Unit tests added; fastlane lanes still pending.)
- [ ] Finalize reusable GitHub Actions workflow for branded repos.

## Build & Run

1. Run `bundle install` / fastlane setup (later) and regenerate the Xcode project when file structure changes:
   ```bash
   cd ios-app-template/TemplateApp
   ruby ../scripts/generate_project.rb
   ```
2. Open `TemplateApp/TemplateApp.xcodeproj` in the latest stable Xcode (currently 26.11 on GitHub runners and local installs).
3. In the *Signing & Capabilities* tab, set your Apple development team and add the **Sign in with Apple** capability.
4. Select the `TemplateApp` scheme and build for an iOS simulator (`⌘B`) or run on device.

## Auth Flow Walkthrough

1. **Hosted UI (Apple / Google)**
   - Configure Cognito Hosted UI with Apple + Google IdPs and provide the client ID, domain, and redirect scheme in `TemplateApp/TemplateApp/Config/app.json`.
   - Ensure the custom URL scheme (`templateapp`) is added under *URL Types* in Info.plist so `ASWebAuthenticationSession` can return to the app.
   - On success the app stores the tokens via `AuthSessionStorage` (UserDefaults placeholder) and triggers `AppState.handleLoginSuccess` to bootstrap the profile.

2. **Native Email Sign-Up**
   - Two screens now drive the flow: Screen 1 captures the email and calls `/v1/auth/email/status` to decide whether the account is new, pending, or already confirmed; Screen 2 locks that email while collecting password, profile details, the verification code, and resend/confirm actions in one place.
   - Uses `/v1/auth/email/signup`, `/confirm`, `/resend`, and the new `/status` endpoint. Creating an account immediately enables the on-page code entry instead of navigating to a separate confirm view.
   - The primary actions stay disabled until the form is valid, and inline status/error messages explain whether the code was sent, pending, or confirmed.

3. **Email Login + Forgot Password**
   - Login posts to `/v1/auth/email/login` and handles common Cognito errors (`UserNotConfirmed`, `NotAuthorized`, etc.).
   - Forgot password now happens on a single sheet: the same form sends the reset code, enforces a cooldown, accepts the verification code + new password, and calls `/v1/auth/email/{forgot,forgot/confirm}` before logging the user back in.

4. **Account Management**
   - `AccountView` fetches `/v1/users/me`, signs out, or calls `DELETE /v1/users/me` after the user types DELETE in a confirmation sheet.
   - Analytics hooks fire on signup/login/resend/delete events.

5. **Environment / Limits**
   - Update `app.json` per brand/environment; the sidebar exposes Terms of Use + Privacy Policy via sheets (placeholders until real URLs are wired).
   - Cognito’s default email quota is ~50/day; configure Amazon SES and set “Message delivery → Send with Amazon SES” in the user pool to raise limits.

## Running Unit Tests

- Unit tests live under `TemplateApp/TemplateAppTests`. Run them from Xcode (`⌘U`) or via CLI:

  ```bash
  cd ios-app-template
  xcodebuild test \
    -project TemplateApp.xcodeproj \
    -scheme TemplateApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=18.3.1'
  ```

## Handoff Notes

- **When you add new template Swift files under `TemplateApp/TemplateApp` (for example new screens, services, or shared components), you must also add them to the `TemplateApp` target in `TemplateApp.xcodeproj` via Xcode’s “Add Files…” / Target Membership UI.** The `ios-app-template/scripts/build_brand.sh` script copies the Xcode project from this template into `brand-builds/app-<brand>`, so any files that aren’t part of the `TemplateApp` target won’t exist in the generated brand projects and will cause “Cannot find X in scope” errors even if the `.swift` file is present on disk.
- Always build with the latest stable Xcode release (right now 26.11) so local runs, CI, and TestFlight uploads all match the same toolchain/iOS SDK combo.
- Build numbers are auto-incremented via `agvtool new-version -all <run#>` inside CI/CD, so you never have to bump `CFBundleVersion` manually before TestFlight.
- Record any secrets required for CI (Apple API key, App Store Connect credentials) once workflows are wired.
- Keep staging API base URLs as defaults; note overrides if testing prod locally.
- Native email sign-up enforces Cognito’s verification code step; testers can resend codes in-app and must type DELETE to remove accounts.
- Hosted UI + native email share the same AppState; if SES/email limits are exceeded Cognito returns `Exceeded daily email limit...` which surfaces directly in the UI.
- Email sign-up & login now automatically detect pending confirmations: if Cognito reports an existing unverified account we resend the code and route the user back into the OTP screen.

- Lightweight analytics hooks fire on email signup/login/resend/delete so downstream apps can route events to their preferred provider.
- Account view offers “Delete account”, which calls the new backend endpoint and then signs the user out.
- New app onboarding: before opening Xcode, run `./scripts/build_brand.sh ../app-<brand> brand-builds` to apply the manifest, then follow `platform-backend/docs/how-to.md` to ensure the backend manifest + API authorizer audiences include the new Cognito client IDs.

## Brand manifest + automation

Every branded app provides an `app.json` that mirrors the template config (`TemplateApp/TemplateApp/Config/app.json`). Minimum shape:

```json
{
  "appId": "com.learnandbecurious.sample",
  "displayName": "Template App",
  "bundleIdSuffix": "sample",
  "theme": {
    "primary": "#111111",
    "accent": "#B8E986",
    "appearance": "system"
  },
  "features": {
    "login": true,
    "feedback": false,
    "cloudSync": false
  },
  "apiBase": {
    "staging": "https://emjv5xdzc3.execute-api.us-west-2.amazonaws.com",
    "prod": "https://api.example.com"
  },
  "auth": {
    "cognitoClientId": "5l0ibjffqpburhckouas7r234d",
    "scheme": "templateapp",
    "region": "us-west-2",
    "hostedUIDomain": "auth-staging.learnandbecurious.com"
  },
  "legal": {
    "privacyUrl": "https://learnandbecurious.com/privacy.html",
    "termsUrl": "https://learnandbecurious.com/terms.html"
  },
  "cloud": {
    "containerId": "iCloud.com.learnandbecurious.sample"
  },
  "activeEnvironment": "staging"
}
```

Each brand repo keeps this manifest at the root (`app.json`) plus optional asset overrides under `Assets/` (e.g., `Assets/AppIcon.appiconset`). During automation the manifest is copied into the template via `scripts/apply_manifest.sh`.

### GitHub Actions build pipeline

Brand repos define a workflow that:

1. Checks out the brand repo (manifest + assets).
2. Checks out this template repo into a sibling directory.
3. Runs `scripts/apply_manifest.sh` to copy the manifest into the template.
4. Runs `xcodebuild test` (optional) and `xcodebuild archive` for the chosen scheme/config.
5. Uploads the `.xcarchive` as a workflow artifact.

`app-sample/.github/workflows/build.yml` contains a ready-to-copy workflow definition. Update the `repository`/`ref` fields to point at this template if you fork/rename it, then run the workflow via **Actions → Run workflow** to produce a fresh archive without opening Xcode locally.

## Brand manifest schema

Each branded app supplies an `app.json` that mirrors the template’s config file (`TemplateApp/TemplateApp/Config/app.json`). A minimal manifest looks like this:

```json
{
  "appId": "com.learnandbecurious.sample",
  "displayName": "Template App",
  "bundleIdSuffix": "template",
  "theme": {
    "primary": "#111111",
    "accent": "#B8E986",
    "appearance": "system"
  },
  "features": {
    "login": true,
    "feedback": false,
    "cloudSync": false
  },
  "apiBase": {
    "staging": "https://emjv5xdzc3.execute-api.us-west-2.amazonaws.com",
    "prod": "https://api.example.com"
  },
  "auth": {
    "cognitoClientId": "5l0ibjffqpburhckouas7r234d",
    "scheme": "templateapp",
    "region": "us-west-2",
    "hostedUIDomain": "auth-staging.learnandbecurious.com"
  },
  "build": {
    "marketingVersion": "1.0.0",
    "buildNumber": "1"
  },
  "cloud": {
    "containerId": "iCloud.com.learnandbecurious.sample"
  },
  "activeEnvironment": "staging"
}
```

Required fields:

- `appId` – fully qualified bundle identifier.
- `displayName` – what appears on the SpringBoard and is used as the main title on the welcome screen.
- `bundleIdSuffix` – appended to the shared bundle ID when templating.
- `theme` – primary/accent colors plus `appearance` (`light`, `dark`, or `system`).
- `features` – booleans to gate UI elements per brand (see `aiPlayground` notes below).
- `cloud` (optional) – CloudKit configuration; `cloud.containerId` defaults to `iCloud.<appId>` when omitted and `features.cloudSync` is true.
- `apiBase` – base URLs for staging/prod API Gateway endpoints.
- `auth` – Cognito client configuration for the brand (client ID, Hosted UI domain, custom URL scheme, AWS region).
- `build` (optional) – `marketingVersion` (`CFBundleShortVersionString`) and `buildNumber` (`CFBundleVersion`). Defaults stay at the template values if omitted.
- `activeEnvironment` – which environment the build should target by default (`staging` or `prod`).

### AI Playground feature flag

The template exposes an optional AI Playground screen controlled entirely by a feature flag:

- Template config (`TemplateApp/TemplateApp/Config/app.json`) and brand manifests must include:

  ```json
  "features": {
    "aiPlayground": true | false,
    "login": true,
    "feedback": false,
    ...
  }
  ```

- `features.aiPlayground` **must be explicitly set** for every brand:
  - Example (sample app): `"aiPlayground": true`
  - Example (Visa app): `"aiPlayground": false`
- The sidebar menu adds an `AI Playground` item only when `features.aiPlayground` is `true`.
- The `SidebarItem` enum includes an `.aiPlayground` case. Any `switch` on `SidebarItem` (including brand overlays under `Overlay/TemplateApp/...`) must handle `.aiPlayground` to remain exhaustive, even if the feature is currently disabled for that brand.

### Cloud Sync feature flag

- Set `features.cloudSync` to `true` to have `scripts/apply_manifest.sh` inject CloudKit entitlements into `TemplateApp/TemplateApp.entitlements`.
- When `features.cloudSync` is true:
  - If `cloud.containerId` is present, that container is used.
  - If `cloud.containerId` is omitted, the default container is `iCloud.<appId>`.
- When `features.cloudSync` is false or omitted, CloudKit entitlement keys are removed from entitlements.
- This only configures app capabilities in the project file. You still need matching iCloud/CloudKit capability enabled for the App ID and provisioning profiles in Apple Developer.

Brand repos keep this manifest at the root (`app.json`) and optional asset overrides under `Assets/` (e.g., `Assets/AppIcon.appiconset`). During automation the manifest is copied verbatim into `TemplateApp/TemplateApp/Config/app.json` via `scripts/apply_manifest.sh`.

## Reusable build workflow

The template exports `.github/workflows/reusable-build.yml`, which can be invoked from any brand repo via `workflow_call`. Inputs:

- `manifest_repo` – GitHub slug for the brand repo (e.g., `frinsan/app-sample`).
- `manifest_ref` – git ref in that repo (`main` by default).
- `manifest_path` – relative path to the manifest file (defaults to `app.json`).
- `scheme`, `configuration`, `run_tests` – optional overrides for the Xcode build.

The workflow:

1. Checks out the template repo (this one) and the brand repo side by side.
2. Runs `scripts/apply_manifest.sh` to copy the manifest into the template.
3. Optionally runs unit tests via `xcodebuild test` on a simulator.
4. Archives the iOS app (`xcodebuild archive`) and uploads the `.xcarchive` as a GitHub artifact.

The manifest script also updates the Xcode project’s bundle identifier, marketing/build versions, Info.plist display name + URL scheme, and overlays any brand-specific `Assets/` contents (e.g., `AppIcon.appiconset`, `LaunchImage.imageset`) onto `TemplateApp/TemplateApp/Assets.xcassets`. Running it locally before opening Xcode keeps Product settings in sync with the manifest so simulator/device builds already reflect the brand.

This lays the groundwork for TestFlight distribution—Fastlane or App Store Connect uploads can be layered on once the shared Apple credentials are in place.

### Brand repo example

`app-sample` contains `.github/workflows/build.yml`, which demonstrates how a brand repo triggers the reusable workflow:

```yaml
name: sample-build

on:
  workflow_dispatch:

jobs:
  build:
    uses: frinsan/ios-app-template/.github/workflows/reusable-build.yml@main
    with:
      manifest_repo: frinsan/app-sample
      manifest_ref: main
      manifest_path: app.json
```

Copy that workflow into each brand repo, adjust the repository/ref/path, and run it from the Actions tab to get a fresh build artifact driven entirely by the manifest.

## Documentation Update (2026-02-28)

This section appends current canonical behavior without deleting prior historical notes/examples.

- Canonical feature flag inventory now lives in:
  - `../FEATURE_FLAGS.md` (workspace root)
- When adding/changing flags, update `../FEATURE_FLAGS.md` first, then update this README if needed.

### Cloud Sync Implementation Notes (Current)

- Cloud sync uses static entitlements switching, not in-place entitlements key mutation.
- `scripts/apply_manifest.sh` toggles `CODE_SIGN_ENTITLEMENTS`:
  - `features.cloudSync=true` -> `TemplateApp/TemplateAppCloud.entitlements`
  - `features.cloudSync=false` -> `TemplateApp/TemplateApp.entitlements`
- Cloud container policy is default-only:
  - runtime container: `iCloud.<appId>`
  - `cloud.containerId` is unsupported and rejected by `scripts/apply_manifest.sh`

Historical examples in this README that include `cloud.containerId` are kept for traceability, but the policy above is the current standard.

## Documentation Update (2026-03-01)

This section records the current template UX behavior without removing older notes above.

- Home screen is intentionally product-like and minimal.
  - Dev/test actions are no longer shown on Home.
- When `features.imageCapture` is `true`, sidebar navigation includes a dedicated `Image Capture` screen.
  - Image Capture flow supports: Upload photo, Take photo, Retake/Replace, Remove, full-screen preview, and saving persisted image test records.
- Settings behavior:
  - User-facing `iCloud Sync` section remains lightweight (toggle + status + user guidance).
  - Non-user diagnostics/actions are grouped under `Developer Tools` and shown only when `activeEnvironment != prod`.
  - Developer Tools currently consolidates:
    - Feature Actions (share, test error toast, request rating)
    - Cloud Diagnostics
    - Cloud Test Records
    - Cloud Maintenance (including delete iCloud data action)
    - Image Record Inspector
