# Release setup (Apple account → fastlane)

One-time setup to enable signed builds, TestFlight, and App Store submission.
The code side is already wired — you only need to supply the values below.

- **Bundle ID:** `com.wac.SwiftBaseClassWAC`
- **Team ID (in project):** `T92Y92RB48` — confirm this matches your account.

---

## 1. Apple Developer Program

1. Sign in at https://developer.apple.com/account.
2. If the membership is **active**, note your **Team ID** and move on. If it
   differs from `T92Y92RB48`, update `DEVELOPMENT_TEAM` in the Xcode project and
   `team_id` in `fastlane/Appfile`.
3. If **not enrolled** → **Enroll** → choose **Organization** (needs a D-U-N-S
   number for the legal entity) or **Individual** → pay the **$99/year** fee.

## 2. Register the App ID

https://developer.apple.com/account/resources/identifiers → **+** → **App IDs**
→ **App** → Explicit Bundle ID `com.wac.SwiftBaseClassWAC` → enable only the
capabilities you use → **Register**.

## 3. Create the app record

https://appstoreconnect.apple.com → **Apps** → **+** → **New App** → iOS, pick a
name + primary language, select the bundle ID, set an SKU → **Create**.

## 4. Generate an App Store Connect API key

App Store Connect → **Users and Access** → **Integrations** → **App Store
Connect API** → **+**. Role **App Manager**.
- **Download the `.p8` once** (you can't re-download it). Save it as
  `fastlane/AuthKey_XXXXXXXXXX.p8` (gitignored).
- Record the **Key ID** and the **Issuer ID** (shown above the key list).

## 5. Create the private `match` signing repo

```bash
gh repo create wac-ios-certificates --private
```
This repo stores your encrypted certs + profiles. It must be **private** and
**separate** from the (public) app repo.

## 6. Fill in credentials

Copy the template and fill it in (this file is gitignored):

```bash
cp fastlane/.env.example fastlane/.env
```

| Variable | Value |
|----------|-------|
| `FASTLANE_APPLE_ID` | your Apple Developer email |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID from step 4 |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Issuer ID from step 4 |
| `APP_STORE_CONNECT_API_KEY_PATH` | path to the `.p8`, e.g. `fastlane/AuthKey_ABC123.p8` |
| `MATCH_GIT_URL` | the signing repo URL from step 5 |
| `MATCH_PASSWORD` | an encryption passphrase you choose (save it!) |

## 7. Generate signing assets, then ship

```bash
bundle install
bundle exec fastlane match appstore   # first run creates + stores cert/profile
bundle exec fastlane beta             # build signed .ipa → upload to TestFlight
```

`bundle exec fastlane release` submits for App Store review.

---

## CI (GitHub Actions secrets)

To run `fastlane beta` from CI, add these under **Settings → Secrets and
variables → Actions** (the workflow currently archives unsigned; switch it to
`bundle exec fastlane beta` once these exist):

- `MATCH_PASSWORD`
- `MATCH_GIT_URL`
- `MATCH_GIT_BASIC_AUTHORIZATION` — base64 of `username:PAT` with read access to
  the private signing repo
- `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY` — the base64-encoded `.p8` contents

> The Fastfile reads all credentials from the environment, so CI just needs
> these set — no code changes required.
