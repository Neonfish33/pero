# Pero roadmap

Principles: offline by default, user-owned data, no telemetry without explicit consent, predictable behavior, and writing quality over feature count.

Current point: **1.0** — Windows, SQLite library, import/export, manual WebDAV sync, GitHub release.

Benchmark (headless `flutter test`, not a release build): 10k characters — ~25 ms per frame, 100k — ~1 s, 500k — tens of seconds (30–50 s). The main cost is laying out one giant `TextSpan`, not highlighting. This sets the priorities below.

## 1.5 — "Reliable Windows"

Goal: a product that is safe to install on a work desktop.

- `LICENSE` (MIT), `CHANGELOG.md`, GitHub Actions: `dart analyze`, `flutter test`, Windows build, automated release.
- Installer (Inno Setup or MSIX): shortcut, uninstall entry, `.md` file association, single instance, deduplication when the same file is opened again.
- Editor: paragraph-level virtualization and incremental highlighting instead of a single `TextSpan` for the whole document.
- Performance target: 100,000 characters without typing jank; 500,000 remain usable for reading and spot edits.
- Linked files: track external changes to `filePath`, warn about disk conflicts.
- Export the whole library to a JSON backup (import already exists), verify crash recovery.
- Tests: `integration_test/`, coverage for `DocumentLibrary` and `DocumentRepository` (SQLite).

Done when: the installer and file association work, 100k characters fit the frame budget, CI is green, and releases are automated.

## 2.0 — "Mobile platforms"

Goal: real Android and iOS support, not a someday promise.

- iOS: `Podfile`, build and tests on macOS, share sheet, document picker, iPad hardware keyboard, safe areas.
- Android: dedicated keystore, ProGuard keep rules, enabled `minify`/`shrink`, APK and AAB, testing on real devices.
- Mobile UI: compact toolbars, gestures, correct Back handling, rotation behavior.
- Secure password storage: Keychain on iOS, Keystore on Android (currently the mobile password lives only in memory).
- WebDAV sync on mobile, verification of Cyrillic, line endings, and large files.

Done when: builds pass, sync does not lose data, and typing/selection work with the on-screen keyboard.

## 2.5 — "Cloud and sync"

Goal: the cloud becomes a reliable background rather than a manual button.

- Automatic sync on a timer and after edits, status indicator, retry queue for network errors.
- Providers beyond WebDAV: Dropbox, Google Drive, OneDrive via OAuth.
- Version history and document snapshots, a conflict-resolution screen instead of automatic copies only.
- Encrypted backups, device-to-device sync without a mandatory account (sync key).
- Diagnostics: sync log, secure token storage.

Done when: conflict scenarios are covered by tests, there are no duplicates, offline work is unaffected, and deletions/renames are predictable.

## 3.0 — "Ecosystem"

Goal: Pero stops being a standalone editor while staying fast.

- Optional accounts and end-to-end device sync.
- Collaborative editing (CRDT), comments and discussions.
- Plugins/extensions, custom themes, PDF and DOCX export.
- Text engine decision: if after 1.5 documents of 1M+ characters and collaboration still hit layout limits — prototype a block/rope engine; otherwise stay on `TextField`.
- AI assistant strictly opt-in, with local models or an explicit network request.

Done when: 1M characters remain responsive, collaboration is conflict-free, and plugins are isolated without slowing the core.

## Decision gates

- **1.5:** if the block-based approach does not meet the frame budget at 100k, prototype a custom engine.
- **2.0:** if IME and on-screen keyboards break input, stabilization beats new features.
- **2.5:** if the WebDAV model is not enough, prioritize OAuth providers and version history.
- **3.0:** build an engine only for 1M+ documents or collaborative editing; until then, optimize the standard editor.

## Out of scope

Telemetry, mandatory accounts, cloud as the only storage, AI without explicit consent. Pero must remain useful without the internet and without registration.
