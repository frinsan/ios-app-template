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
2. Open `TemplateApp/TemplateApp.xcodeproj` in Xcode 15.4+.
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

- Xcode 15.4+ required (compiled against iOS 17 SDK).
- Record any secrets required for CI (Apple API key, App Store Connect credentials) once workflows are wired.
- Keep staging API base URLs as defaults; note overrides if testing prod locally.
- Native email sign-up enforces Cognito’s verification code step; testers can resend codes in-app and must type DELETE to remove accounts.
- Hosted UI + native email share the same AppState; if SES/email limits are exceeded Cognito returns `Exceeded daily email limit...` which surfaces directly in the UI.
- Email sign-up & login now automatically detect pending confirmations: if Cognito reports an existing unverified account we resend the code and route the user back into the OTP screen.

- Lightweight analytics hooks fire on email signup/login/resend/delete so downstream apps can route events to their preferred provider.
- Account view offers “Delete account”, which calls the new backend endpoint and then signs the user out.

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
    "feedback": false
  },
  "apiBase": {
    "staging": "https://emjv5xdzc3.execute-api.us-west-2.amazonaws.com",
    "prod": "https://api.example.com"
  },
  "auth": {
    "cognitoClientId": "5l0ibjffqpburhckouas7r234d",
    "scheme": "templateapp",
    "region": "us-west-2",
    "hostedUIDomain": "learnandbecurious-staging.auth.us-west-2.amazoncognito.com"
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
    "feedback": false
  },
  "apiBase": {
    "staging": "https://emjv5xdzc3.execute-api.us-west-2.amazonaws.com",
    "prod": "https://api.example.com"
  },
  "auth": {
    "cognitoClientId": "5l0ibjffqpburhckouas7r234d",
    "scheme": "templateapp",
    "region": "us-west-2",
    "hostedUIDomain": "learnandbecurious-staging.auth.us-west-2.amazoncognito.com"
  },
  "activeEnvironment": "staging"
}
```

Required fields:

- `appId` – fully qualified bundle identifier.
- `displayName` – what appears on the SpringBoard.
- `bundleIdSuffix` – appended to the shared bundle ID when templating.
- `theme` – primary/accent colors plus `appearance` (`light`, `dark`, or `system`).
- `features` – booleans to gate UI elements per brand.
- `apiBase` – base URLs for staging/prod API Gateway endpoints.
- `auth` – Cognito client configuration for the brand (client ID, Hosted UI domain, custom URL scheme, AWS region).
- `activeEnvironment` – which environment the build should target by default (`staging` or `prod`).

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
