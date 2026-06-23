# Cairn — Privacy Policy

> **Canonical version.** The published, authoritative copy of this policy is at
> <https://luminaapps.com/cairn-privacy.html>. This file is the in-repo source,
> kept in sync for version history; if the two ever differ, the published page
> wins. Keep the published copy on a **public, non-geofenced HTTPS URL** (Apple
> and Google both require this), and make sure the Apple **App Privacy** label
> and Google Play **Data safety** form say the same thing. Not legal advice —
> adapt to your jurisdiction (e.g. EU/GDPR) as needed.

**Last updated:** 2026-06-23

## The short version

Cairn reads health and fitness data from your phone's health store (Apple
Health on iOS, Health Connect on Android), turns it into open-format files, and
syncs those files to **your own Nextcloud**. That's it.

- **The developer of Cairn collects nothing and stores nothing.** There is no
  Cairn server, account, or database. Your data goes from your device to the
  Nextcloud server *you* control.
- **Cairn only reads** your health store — it never writes back to it.
- **No advertising, no marketing, no data mining, no profiling, no analytics,
  no third-party trackers or SDKs.**

## Who this applies to

This policy covers the **Cairn mobile app** (Android and iOS). An optional,
separate Nextcloud web app (read-only over the same files on your own server) is
covered by the same principles; it adds no new data collection.

## What data Cairn accesses, and why

| Data | Source | Why | Where it goes |
| --- | --- | --- | --- |
| Health & fitness readings — heart rate, steps, body weight, sleep, workouts/exercise (and the distance & calories attached to a workout) | Apple Health / Health Connect, **read-only**, with your permission | To show your dashboard and to save your history as files | Local cache on your device; your Nextcloud |
| Profile you enter — height and date of birth | You type it in Settings | To compute your BMI and show your age | Local cache on your device; your Nextcloud (`profile.json`) |
| Nextcloud connection — your server address and an app-specific password (token) | The Nextcloud login you complete | To upload your files over WebDAV | Your device's secure storage only (Keychain / Android Keystore) |

Cairn requests only the health permissions it uses, all **read-only**. It never
requests or holds write access to your health store.

## Where your data lives, and who can see it

- **On your device** — a local cache of your readings, plus the Nextcloud token
  in the operating system's secure storage.
- **In your Nextcloud** — your readings and profile, as open
  [Open mHealth](https://www.openmhealth.org/) / IEEE 1752.1 JSON files under a
  `/Cairn/` folder. **You** own and control this server.
- **Nowhere else.** There is no central Cairn server. The developer has **no
  access** to your data and receives nothing. Your Apple Health / Health Connect
  data is **never** stored in iCloud or any developer or third-party cloud — only
  in the Nextcloud you choose.

## Sharing

Cairn does **not** share your data with anyone. There are no third-party
analytics, advertising, or tracking services, and no third-party data
processors. The only network connection Cairn makes is, over HTTPS, to the
Nextcloud server you configured.

## Security

- All sync traffic uses **HTTPS**; Cairn refuses non-HTTPS Nextcloud servers.
- Cairn never stores your main Nextcloud password — only a **revocable,
  app-specific token**, kept in the operating system's secure storage
  (Keychain on iOS, Keystore on Android). You can revoke it at any time from
  your Nextcloud security settings.

## Keeping or deleting your data

You are always in control:

- **Stop new data:** revoke Cairn's permissions in Apple Health / Health
  Connect, or disconnect Nextcloud in Cairn's Settings.
- **Remove the connection:** "Disconnect" in Settings clears the stored token;
  uninstalling the app removes the local cache and the token from your device.
- **Delete your history:** delete the `/Cairn/` folder in your Nextcloud (and,
  if desired, revoke the app password in Nextcloud).

Cairn keeps no copy anywhere else, so there is nothing for the developer to
delete on your behalf — deleting the files on your own server is the complete
erasure.

## Children

Cairn is not directed at children and does not knowingly collect data from
children.

## Not a medical device

Cairn aggregates and visualizes your existing health data. It does **not**
provide medical advice, diagnosis, or treatment, and makes no clinical claims.

## Changes to this policy

If this policy changes, the "Last updated" date above will change and the new
version will be published at the same URL.

## Contact

Questions about this policy or your privacy: email <luminaapps@gmail.com>, or
open an issue at <https://github.com/LuminaAppsDev/cairn/issues>.
