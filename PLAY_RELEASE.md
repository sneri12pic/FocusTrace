# FocusTrace — Play Console release checklist

Store copy and form answers for the Android release with optional account and cloud sync. Do these in order in https://play.google.com/console. Checked against the implementation on September 30, 2026; deployment checks below remain required before submission.

## 0. One-time setup
- [ ] Developer account ($25 one-time). New **personal** accounts must run a closed test with **12+ testers for 14 days** before production access — plan for it.
- [ ] **Back up `upload-keystore.jks` and the `key.properties` passwords off this machine** (password manager + cloud drive). Losing the keystore means you can never update the app.
- [ ] Publish the updated `docs/` pages. Expected GitHub Pages setup: repo Settings → Pages → Deploy from branch → `master`, folder `/docs`; verify the actual configuration. Both the privacy and account-deletion URLs in section 3 must load publicly with the updated copy before submission.

## 1. Create app
- App name: **FocusTrace**
- Default language: English (US) · App (not game) · **Free**

## 2. Store listing

**Short description (max 80 chars):**
> Track screen time and limit apps. Offline, with optional cloud sync. No ads.

**Full description:**
> FocusTrace helps you understand and control your screen time. Tracking and app limits work offline, without an account.
>
> Local first, with optional sync
> • Use tracking, restrictions and blocking without signing in.
> • Optionally create an account and turn on cloud sync for your daily app-usage totals. Sync is off by default.
> • Creating an account or signing in sends your email and password to the FocusTrace server, which stores a password hash.
> • With sync enabled, device information and daily app names, package names, time spent and launch counts are sent over HTTPS, manually and periodically in the background.
> • No ads or analytics SDKs. Your restrictions, schedules and detailed usage timelines stay on your device.
> • Turn sync off anytime. Delete your cloud account and synced history from Settings; clear local data separately.
>
> Understand your usage
> • Daily dashboard of your app usage and totals.
> • Playful bubble chart that shows where your time really goes.
> • Home-screen widgets for at-a-glance stats.
>
> Take back control
> • Set daily limits for distracting apps.
> • A gentle blocking overlay steps in when a limit is reached.
> • Exclude apps you don't want tracked.
>
> Available in English, Deutsch, Español, Français, Português (Brasil), 日本語, and Українська.
>
> FocusTrace uses usage access to measure screen time and display-over-apps permission to show a blocking screen when your limits are reached. Installed-app access supplies app names and icons. Network access supports the optional account and cloud sync; local tracking and blocking keep working without a connection.

**Graphics:** app icon 512×512, feature graphic 1024×500, ≥2 phone screenshots (capture from the phone after the release build is verified).

## 3. Privacy policy and account deletion

Privacy policy URL: `https://sneri12pic.github.io/activityTracker/privacy.html`

Account-deletion URL (also enter in Data safety): `https://sneri12pic.github.io/activityTracker/delete-account.html`

- In app: **Settings → Account & sync → Delete account**, confirmed with the current password. Successful deletion removes the server account, password hash, sessions/tokens, registered devices and synced usage from every device. Local usage, restrictions and settings remain.
- Without the app: the deletion page directs users to email `ypodev.official@gmail.com` from their account address. The operator must process these requests and confirm completion; the page does not promise a response time.
- Turning sync off, logging out, clearing local data or uninstalling does **not** delete the cloud account or its existing history. **Settings → Clear local data** erases the local copy separately.
- Synced history remains until account deletion. Security logs can retain an internal account ID for deletion events and source IPs for rate-limit events. Before deployment, reconcile log and backup retention with the published policy and deletion page; do not promise immediate erasure from backups unless the deployed procedure supports it.

## 4. Data safety form

Use **App content → Data safety**. Optional uploads still count as collection, including uploads to the developer's own server. These answers describe the current code and must match the deployed service and all distributed versions. See [Google Play's Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en).

- Collect or share required user data types? → **Yes**.
- All collected data encrypted in transit? → **Yes**, for the release build using the verified HTTPS endpoint. The release URL gate rejects non-HTTPS configuration; complete the device/network verification in section 7 before submitting this answer. This is transport encryption, not end-to-end encryption: the server can read synced data.
- Account creation method → **Username and password** (email is the username; no OAuth or social sign-in).
- Account/data deletion available? → **Yes**; use the URL and paths in section 3. See [Google Play's account-deletion requirements](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en).
- Delete collected data without deleting the account? → **No** for cloud data; there is no separate synced-history deletion feature. Clearing local data is not cloud deletion.

For each row below: **Collected: Yes; Shared: No; Optional: Yes; Ephemeral: No**. Users can use the core app without an account; usage uploads additionally require **Sync this device**. Stored hashes, random IDs and retained security logs are not anonymous or ephemeral merely because they omit a name.

| Play data type | What FocusTrace sends or retains | Collection purposes |
| --- | --- | --- |
| Personal info → Email address | Email at registration/sign-in; stored for the account and used for login rate limits. | Account management; App functionality; Fraud prevention, security, and compliance |
| Personal info → User IDs | Account ID carried by authenticated requests and retained in session records and some security events. | Account management; App functionality; Fraud prevention, security, and compliance |
| Personal info → Other info | Password at registration/sign-in and deletion confirmation; server stores an Argon2id hash, not plaintext. | Account management; App functionality; Fraud prevention, security, and compliance |
| App activity → Installed apps | Package and display names for apps in uploaded daily usage, not the entire installed-app inventory or icons. | App functionality |
| App activity → App interactions | Per-app daily seconds and launch counts, date, time zone, snapshot timestamp and completeness status. No raw event/session timeline. | App functionality |
| Device or other IDs → Device or other IDs | Random installation UUID with model name/platform and registration/last-seen timestamps; source IP used for abuse controls and logged on source rate limiting. No hardware or advertising ID. | App functionality; Fraud prevention, security, and compliance |

The category mapping is our interpretation of the payloads using Google's definitions, including **Other info** for the password and **App interactions** for usage totals. The model name is not the user's personal name. IPs are used for security, not to infer location; the current service does not collect location. Review any new proxy, hosting or logging behavior before submission.

**Shared: No** describes the current first-party sync flow. Confirm any hosting/service-provider arrangements before submitting; there are no advertising or analytics SDKs in the current app. Usage summaries are an app feature, not developer analytics. Do not select advertising, marketing, personalization or developer communications for these flows. Do not claim an independent security review.

Implementation references: `lib/src/data/datasources/focus_trace_sync_api.dart`, `lib/src/domain/models/sync_usage.dart`, `server/src/main/java/com/stepandemianenko/focustrace/sync/auth/AuthRateLimiter.java`, and `docs/backend/backend-sync-architecture.md` sections 5.1 and 11. The public policy is `docs/privacy.html`.

## 5. Permission declaration forms (App content → Sensitive permissions)

**QUERY_ALL_PACKAGES** — core purpose: *Device search / app management* (screen-time tracking).
> FocusTrace is a screen-time tracker and app limiter. Its core function is to display usage statistics and enforce user-configured limits for any app installed on the device. QUERY_ALL_PACKAGES is required to resolve human-readable names and icons for every installed app the user may track, restrict, or exclude. A targeted <queries> filter is not viable because the set of apps is chosen by the user from all installed apps and cannot be known in advance. Names and icons are resolved locally. If the user creates an account and enables cloud sync, package names and display names for apps in daily usage are uploaded with their daily totals to the FocusTrace server. Icons and the full installed-app inventory are not uploaded. Installed-app information is not used for advertising or analytics.

**Usage access (PACKAGE_USAGE_STATS):**
> Measuring per-app screen time is the app's core purpose. UsageStats data is aggregated into the user's private on-device database to show usage summaries and enforce the user's own app limits. If the user signs in and enables cloud sync, daily per-app totals and launch counts, app identifiers/names and day metadata are uploaded to the FocusTrace server over HTTPS. Raw usage events and detailed session timelines are not uploaded. Tracking and enforcement work offline without an account.

**Foreground service (FOREGROUND_SERVICE_SPECIAL_USE, subtype `screen_time_app_restrictions`):**
> The service continuously checks the foreground app against user-configured screen-time restrictions and shows a blocking overlay when a limit is reached. Enforcement must run while other apps are in the foreground, which no other service type or WorkManager pattern supports.

**Display over other apps (SYSTEM_ALERT_WINDOW):** requested at runtime during onboarding; used only to show the limit-reached blocking screen.

**Network access (INTERNET; normal permission, no runtime prompt):**
> Used for optional account registration, sign-in, session refresh, logout, account deletion and cloud sync. Account requests send credentials even before usage sync is enabled. Daily usage uploads require opt-in. Release builds use HTTPS; local tracking, limits and blocking do not depend on the network.

**Notifications (POST_NOTIFICATIONS), foreground service and run at boot (RECEIVE_BOOT_COMPLETED):** support local restriction enforcement and its status notification. Periodic cloud sync uses WorkManager separately; the restriction service does not require cloud access.

## 6. App content declarations
- Content rating questionnaire: utility/productivity, no user-generated content, no violence → expect "Everyone".
- Target audience: **18+** (or 13+; do NOT tick under-13 — avoids Families policy).
- News app: No · COVID app: No · Government app: No
- Ads: **No** · In-app purchases: **No**

## 7. Release

Before uploading a build that advertises sync:

- [ ] Complete the hardware restore/device-transfer and real-network checks in `docs/backend/backend-sync-v1-plan.md`, including sign-in, opt-in, manual/background sync, offline recovery and account deletion on a release APK. Also verify an HTTP-configured release exposes no sync UI and sends no sync requests.
- [ ] Deploy and verify the HTTPS service, proxy and backups. Confirm retention/deletion handling for logs and backups; align section 3 and the public pages with the deployed behavior.
- [ ] Publish and open both URLs in section 3 without signing in. Verify the support mailbox and the manual account-deletion procedure.
- [ ] Enter the updated store copy, permission explanations, Data safety answers and deletion URL in Play Console. For app review, supply working access instructions and a dedicated test account for the optional signed-in features through **App access**; keep its credentials out of this repository.

1. Replace the example host with the verified release endpoint, then build: `flutter build appbundle --release --dart-define=FOCUSTRACE_SYNC_BASE_URL=https://sync.example.com`. Upload `build/app/outputs/bundle/release/app-release.aab` to **Closed testing** only after the checks above. Omitting the define hides account/sync UI; an unconfigured build must not be advertised as supporting sync.
2. Add 12+ tester emails (Google Groups link works well), share the opt-in URL.
3. After 14 days with 12 testers, apply for production access, then promote the same build.
4. Each new upload: bump `version:` in pubspec.yaml (e.g. `1.0.1+2` — the `+N` is the versionCode and must increase).

## 8. Post-launch (no SDKs needed)
- Crashes & ANRs: Play Console → Quality → Android vitals.
- User feedback: Play reviews + the in-app "Send feedback" mail link.
