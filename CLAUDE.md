# Project: Cairn

## What This Project Does

Personal health-data aggregator. A Flutter app (iOS + Android) reads the
platform-native health store (Apple HealthKit / Android Health Connect),
normalizes readings into open Open mHealth / IEEE 1752.1 JSON-Lines files, and
syncs them via WebDAV into the user's *own* Nextcloud. No central server, no
proprietary database — the Nextcloud files are the system of record. A later,
optional read-only Nextcloud web app (PHP + Vue) is a second frontend over the
same files. Full design: `docs/DESIGN.md`.

## Stack

- **Language:** Dart (Flutter, single codebase iOS + Android); later PHP + Vue
- **Build/Run:** Flutter SDK (`flutter pub get`, `flutter run`)
- **Test:** `flutter test`; validate emitted OMH against the schema lib in tests
- **Key deps:** `health` package (HealthKit + Health Connect), WebDAV/Nextcloud
  Login Flow v2, OS secure storage (Keychain / Android Keystore)
- **Lint:** `very_good_analysis` + `strict-casts`/`strict-inference`/
  `strict-raw-types` (`analysis_options.yaml`); zero analyzer warnings, CI treats
  lints as errors

## Directory Layout

Greenfield — only `docs/` exists today. Planned Flutter layout:

```
lib/        → app source: health read, OMH mapping, WebDAV sync, dashboard (PLANNED)
test/       → unit/widget tests incl. OMH schema validation (PLANNED)
docs/       → DESIGN.md (authoritative design doc) — EXISTS
```

Scaffold the app with `flutter create`.

## Essential Commands

```bash
flutter pub get                                     # deps
flutter run                                         # run on device/emulator
flutter test                                        # tests

# Lint / format (must pass before committing)
dart format .
dart analyze                                        # or: flutter analyze
dart format --output=none --set-exit-if-changed .   # CI format gate
```

## Project-Specific Rules

- **Pre-commit gate (binding).** Before every commit, run `/review` and
  `/security-audit` and address all findings — fix them, or get explicit user
  sign-off to defer with a tracked follow-up. No commit ships with unresolved
  findings from either skill. Applies to every commit, including small ones.
  Document changes in `CHANGELOG.md`, following its category convention.
- **Final fmt pass before staging (binding).** The very last action before
  `git add` is `dart format .` then `dart format --output=none
  --set-exit-if-changed .`. The `--set-exit-if-changed` run asserts the working
  tree matches what CI's format check runs. A fmt run earlier in the gate is
  **not** sufficient — every subsequent edit invalidates that snapshot, so
  re-run it immediately before staging.
- **Files are the single source of truth.** The OMH / IEEE 1752.1 JSON-Lines
  files in the user's Nextcloud are authoritative. Never introduce a central
  server or database as the system of record.
- **Append-only, never rewrite.** One `.jsonl` per metric per day; writes are
  line appends. Rewriting a growing file invites Nextcloud conflict copies.
- **Read-only on the OS health store.** Cairn *reads* HealthKit / Health Connect;
  it never writes back. Handle partial permission grants per-type. iOS hides
  HealthKit read-auth status — design around *data presence*, not a permission
  boolean. Health Connect perms are revocable; re-check before each sync.
- **Format care.** Validate emitted OMH against the schema library in tests;
  units come from the schema (no ad-hoc units); custom metrics use
  `namespace: "cairn"`. Bump `manifest.json` `format_version` and ship a
  migration on any breaking format change — it is every user's whole history.
- **Auth.** Nextcloud Login Flow v2 app tokens in OS secure storage only — never
  the user's main password.

## Skills Available

- `codebase-navigator` — use when first exploring this repo
- `code-quality` — use before committing any changes

## See Also

- `docs/DESIGN.md` — full design doc and source of truth for all decisions above
