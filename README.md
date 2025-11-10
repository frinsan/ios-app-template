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
   - Forgot password resides on a modal sheet: request screen posts to `/v1/auth/email/forgot`, confirmation screen posts to `/forgot/confirm`, then automatically logs the user in.

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
