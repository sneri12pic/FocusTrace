# FocusTrace — Play Console release checklist

Ready-to-paste text for every form. Do these in order in https://play.google.com/console.

## 0. One-time setup
- [ ] Developer account ($25 one-time). New **personal** accounts must run a closed test with **12+ testers for 14 days** before production access — plan for it.
- [ ] **Back up `upload-keystore.jks` and the `key.properties` passwords off this machine** (password manager + cloud drive). Losing the keystore means you can never update the app.
- [ ] Enable GitHub Pages: repo Settings → Pages → Deploy from branch → `master`, folder `/docs`. Verify https://sneri12pic.github.io/activityTracker/privacy.html loads.

## 1. Create app
- App name: **FocusTrace**
- Default language: English (US) · App (not game) · **Free**

## 2. Store listing

**Short description (max 80 chars):**
> Private screen-time tracker. All data stays on your device. No ads, no cloud.

**Full description:**
> FocusTrace helps you understand and control your screen time — without giving your data to anyone.
>
> 100% private, by design
> • All data stays on your device. No account, no cloud, no ads, no analytics.
> • The app makes zero network connections. Nothing is collected or shared, ever.
> • Delete everything anytime with one tap.
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
> FocusTrace asks for usage-access and display-over-apps permissions because measuring screen time and enforcing your limits is the app's entire purpose — the data those permissions expose never leaves your phone.

**Graphics:** app icon 512×512, feature graphic 1024×500, ≥2 phone screenshots (capture from the phone after the release build is verified).

## 3. Privacy policy
URL: `https://sneri12pic.github.io/activityTracker/privacy.html`

## 4. Data safety form
- Does your app collect or share any of the required user data types? → **No**
- Data encrypted in transit? / deletion request? → not applicable (no collection)
- Result shown to users: "No data collected · No data shared with third parties".

## 5. Permission declaration forms (App content → Sensitive permissions)

**QUERY_ALL_PACKAGES** — core purpose: *Device search / app management* (screen-time tracking).
> FocusTrace is a screen-time tracker and app limiter. Its core function is to display usage statistics and enforce user-configured limits for any app installed on the device. QUERY_ALL_PACKAGES is required to resolve human-readable names and icons for every installed app the user may track, restrict, or exclude. A targeted <queries> filter is not viable because the set of apps is chosen by the user from all installed apps and cannot be known in advance. All information is processed and stored locally; the app has no network access.

**Usage access (PACKAGE_USAGE_STATS):**
> Measuring per-app screen time is the app's single core purpose. UsageStats data is aggregated into the user's private on-device database to show usage summaries and enforce the user's own app limits. The data is never transmitted off the device.

**Foreground service (FOREGROUND_SERVICE_SPECIAL_USE, subtype `screen_time_app_restrictions`):**
> The service continuously checks the foreground app against user-configured screen-time restrictions and shows a blocking overlay when a limit is reached. Enforcement must run while other apps are in the foreground, which no other service type or WorkManager pattern supports.

**Display over other apps (SYSTEM_ALERT_WINDOW):** requested at runtime during onboarding; used only to show the limit-reached blocking screen.

## 6. App content declarations
- Content rating questionnaire: utility/productivity, no user-generated content, no violence → expect "Everyone".
- Target audience: **18+** (or 13+; do NOT tick under-13 — avoids Families policy).
- News app: No · COVID app: No · Government app: No
- Ads: **No** · In-app purchases: **No**

## 7. Release
1. `flutter build appbundle --release` → upload `build/app/outputs/bundle/release/app-release.aab` to **Closed testing** track.
2. Add 12+ tester emails (Google Groups link works well), share the opt-in URL.
3. After 14 days with 12 testers, apply for production access, then promote the same build.
4. Each new upload: bump `version:` in pubspec.yaml (e.g. `1.0.1+2` — the `+N` is the versionCode and must increase).

## 8. Post-launch (no SDKs needed)
- Crashes & ANRs: Play Console → Quality → Android vitals.
- User feedback: Play reviews + the in-app "Send feedback" mail link.
