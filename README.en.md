# Pero

[Русский](README.md) · **English**

A quiet offline Markdown editor in the spirit of iA Writer. One Flutter codebase for Windows, Android, and iOS.

The goal is not to clone iA Writer literally, but to carry over its philosophy: minimal interface, focus mode, typewriter mode, Markdown highlighting right in the text, instant response, and full operation without the internet. The starting point was the `pero.html` prototype.

Roadmap: [ROADMAP.en.md](ROADMAP.en.md).

## Roadmap status

- [x] Stage 1. Foundation: project, fonts, themes, settings, document model.
- [x] Stage 2. Editor: Markdown highlighting, focus, typewriter, statistics, keyboard shortcuts, automatic list continuation.
- [x] Stage 3. Storage: SQLite, document library, autosave, recovery after restart.
- [x] Stage 4. Preview and polish: native preview, import/export, HTML export, Markdown guide, legacy document migration, mobile file dialogs, release builds.

## What is implemented

### Writing

- Markdown highlighting directly in the editor: headings, lists, quotes, code blocks, links, bold and italic.
- Focus mode: dims everything except the current sentence or paragraph. For list items, quotes, and headings, the "Sentence" mode highlights the current line.
- Typewriter mode: keeps the cursor line vertically centered. The extra height comes from a `SingleChildScrollView` (50% padding at the top and bottom) rather than `InputDecoration.contentPadding`, so the input area is not compressed and letters are not clipped. The line is re-centered when the window height changes.
- Automatic continuation of bulleted and numbered lists on `Enter`.
- Undo/redo and system selection are native Flutter capabilities.
- Three fonts: IBM Plex Mono, Inter, Source Serif 4 (Cyrillic included). Font size is adjustable.
- Themes: light, dark, auto (follows the system).
- Column width: narrow (680), normal (860, default), wide (1040).
- Word, character, and reading time counters; for selections, separately.
- Shortcuts in Windows: `Ctrl + B`, `Ctrl + I`, `Ctrl + E`, `Ctrl + N`, `Ctrl + F`. A future macOS build will use `⌘` instead of `Ctrl`.

### Documents

- Document library: create, search, rename via the first line, delete with a two-step confirmation.
- Autosave to SQLite with debounce (~450 ms), library restored after restart.
- Welcome document on first launch.
- "Markdown Guide" is a regular document with markup examples. Open it with the `?` button in the document list header or via the `⋮` menu → "Markdown Guide".
- Import and export `.md`, export HTML, copy Markdown and HTML to the clipboard.
- Import of a legacy browser backup (JSON): documents keep their original IDs and dates, duplicates are not created; font, theme, focus, and typewriter settings are migrated too.
- On Android and iOS, Markdown and HTML export opens the system share sheet; import uses the system file picker with MIME types and UTIs.

### Cloud

- Manual WebDAV synchronization: Yandex.Disk, Nextcloud, ownCloud, and other servers.
- Each document is a separate `.md` file in the selected cloud folder; the library stays local and works offline.
- On conflict, both versions are preserved: the cloud copy is added as a document marked "conflict".
- The password is encrypted with Windows DPAPI and stored in `shared_preferences` only as ciphertext; other settings are stored as plain text.
- A dedicated dialog: server address, login, app password, folder, connection test, and sync report.

### Interface

- Responsive layout: a permanent sidebar on wide screens, a drawer on narrow ones.
- The top bar (title, menu, preview) hides while typing and returns when the mouse moves.
- The bottom bar (focus, typewriter, font, size, theme, column width, statistics) is always visible.
- The Windows window opens maximized.

## Running

```powershell
flutter pub get
flutter run -d windows
```

Tests and analysis:

```powershell
dart analyze
flutter test
```

## Building for Windows

### Cyrillic path workaround

Flutter tooling on Windows handles Cyrillic paths poorly. The project lives in `C:\Users\yagan\Downloads\аналог ia writer\pero`, so a junction to the short 8.3 folder name (`IAWRIT~1`) is used for builds:

```
C:\src\pero -> C:\Users\yagan\Downloads\IAWRIT~1\pero
```

Build from `C:\src\pero`. If the project is moved, recreate the junction.

```powershell
flutter build windows --debug
# result: C:\src\pero\build\windows\x64\runner\Debug\pero.exe
```

### Release build

`flutter build windows --release` through the junction still fails: MSBuild receives the real long path with Cyrillic characters and cannot read `app.dill`. Release builds must be done in a separate ASCII folder. The whole cycle is automated:

```powershell
powershell -ExecutionPolicy Bypass -File tool/build_windows_release.ps1
```

The script syncs the sources to `C:\pero_build`, runs `flutter clean`, `pub get`, prepares plugin junctions, builds the release, and updates `dist/pero-windows-x64/` together with the `dist/pero-windows-x64.zip` archive.

Manually:

```powershell
robocopy "C:\Users\yagan\Downloads\аналог ia writer\pero" "C:\pero_build" /E /XD build .dart_tool .git ephemeral dist
cd C:\pero_build
flutter pub get
powershell -ExecutionPolicy Bypass -File tool/prepare_windows_links.ps1
flutter build windows --release
```

The runnable bundle is in `dist/pero-windows-x64/` (`pero.exe` + DLLs + `data/`). It must be started from the folder as a whole; a standalone `pero.exe` without the neighboring files will not work. The archive `dist/pero-windows-x64.zip` is there as well.

### Icon, metadata, and window

- Custom application icon: `windows/runner/resources/app_icon.ico` (sizes 16–256, a serif "П" on a paper background). It is also shown in the taskbar and Explorer.
- Exe metadata in `windows/runner/Runner.rc`: "Перо — редактор Markdown"; the version comes from `pubspec.yaml`. `CompanyName`/`ProductName` are intentionally kept as `com.pero`/`pero`: the data path `%APPDATA%\com.pero\pero` depends on them, so they must not be renamed.
- Minimum window size is 560×420 logical pixels, scaled for DPI; the window still opens maximized and the dark title bar follows the system theme.

### Opening `.md` from Explorer

The app accepts a file path in its command-line arguments. Just choose `pero.exe` via "Open with" for `.md`, `.markdown`, or `.txt` — the file is imported into the library and opened. A permanent file association can be enabled manually or by a future installer.

## Building for Android (APK)

Built from the ASCII folder `C:\pero_build` (Gradle also dislikes Cyrillic paths). Android SDK, JDK 17+, and internet access are required: Flutter installs NDK `28.2.13676358` and CMake `3.22.1` itself (SDK licenses must be accepted).

```powershell
cd C:\pero_build
flutter build apk --release   # or --debug
```

The result is a universal APK (arm64-v8a, armeabi-v7a, x86_64):

```
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/flutter-apk/app-debug.apk
```

Copies are placed in `dist/pero-release.apk` and `dist/pero-debug.apk`. The release is signed with the template's debug key — fine for installing and testing on a device, but a proper key is required for Play publishing.

The APKs currently in `dist/` were built from a snapshot before version 1.0.0 and do not include the latest changes — rebuild them before continuing work on mobile platforms.

In `android/app/build.gradle.kts`, `isMinifyEnabled` and `isShrinkResources` are disabled for release. Otherwise R8 renames `kotlin.coroutines.Continuation` and breaks the suspend methods of Pigeon plugins: the app crashes at startup with `PlatformException ... NoSuchMethodError ... SharedPreferencesApiRegistrar.getAll`. Losing minification is acceptable for testing; ProGuard keep rules will be needed for release.

Installing on a device: enable "Install from unknown sources" and open the APK, or

```powershell
adb install dist\pero-release.apk
```

### Plugin symlinks

Flutter creates symlinks for plugins. If the build fails with `Building with plugins requires symlink support`:

1. A no-admin approach — create the junction links in advance:

   ```powershell
   powershell -ExecutionPolicy Bypass -File tool/prepare_windows_links.ps1
   flutter build windows --debug
   ```

2. Or enable Developer Mode (`ms-settings:developers`) and sign in again, or run the build as administrator.

After `flutter clean` or `flutter pub get`, the junctions may be needed again — re-run the script.

## Technologies

- Flutter 3.47.7 (stable), Dart 3.13.5.
- Dependencies: `provider`, `shared_preferences`, `path_provider`, `sqlite3` 3.7.1, `file_selector`, `share_plus`, `win32`, `ffi`, `markdown`, `characters`, `flutter_localizations`.
- SQLite is accessed directly through `sqlite3` (native assets), without `sqlite3_flutter_libs`.
- The interface is localized in Russian.

## Data

On Windows:

```
%APPDATA%\com.pero\pero\pero.sqlite               — documents and sync state
%APPDATA%\com.pero\pero\shared_preferences.json   — settings and cloud options
```

The WebDAV password is not stored in these files in plain text: it is encrypted with DPAPI (Windows) and written to `shared_preferences` only as ciphertext. On other platforms the password currently lives only in memory until the app closes.

The Markdown files folder is not synchronized automatically: import and export are explicit actions.

## Cloud synchronization (WebDAV)

Open the `⋮` menu → "Cloud (WebDAV)…" and fill in:

- **Server address**: for example, `https://webdav.yandex.ru` or your Nextcloud WebDAV address.
- **Login** and **app password**. For Yandex.Disk, create an app password at `id.yandex.ru` → "Security" → "App passwords" → "Files".
- **Cloud folder**: `pero` by default. Nested folders are created automatically.

The "Test" button creates the folder if needed and reads its contents. The "Synchronize" button starts a manual sync: the app never accesses the network on its own.

How it works:

- Each document is stored in the cloud as `<id>.md`. The file name does not depend on the title, so renaming a document does not create duplicates.
- New and modified local documents are uploaded; documents modified in the cloud are downloaded.
- If a document changed both locally and in the cloud, the local version is kept and the cloud version is added to the library as "Title (conflict DD.MM.YYYY HH:MM)". Nothing is lost.
- Deleting a document in the app deletes its cloud file. If a file disappears from the cloud while the local document remains, it is uploaded again.
- The report shows how many files were uploaded, downloaded, deleted, and how many conflicts occurred; per-file errors do not abort the sync.

## Migrating from the old browser version

The old version stores documents in the browser's `localStorage` under the `pero` key. To move them to Pero:

1. Open the old version in a browser and run this in the developer console:

   ```js
   copy(localStorage.getItem('pero'))
   ```

2. Paste the copied text into a file, for example `pero-backup.json`.
3. In the new app: `⋮` menu → "Import backup (JSON)…" and pick the file.

The import understands the old `{docs: [{id, text, t}]}` format and the generic `{documents: [...]}` format. IDs and dates are preserved, and repeated imports do not create duplicates. Unknown settings are ignored, and the font size is clamped to 13–30.

## Performance

A built-in benchmark measures highlighting, layout, and paint for 10k, 100k, and 500k character documents:

```powershell
flutter test benchmark/editor_benchmark_test.dart -r expanded
```

The benchmark is not part of the regular `flutter test` run. Measurements in the headless test (not a release build) on the development machine: 10k — ~25 ms, 100k — ~1 s, 500k — tens of seconds (30–50 s) per frame. The main cost is laying out a single `TextSpan` for the whole document, not highlighting. The next step is therefore paragraph-level virtualization (stage 1.5), not a custom text engine.

## Tests and quality

- `dart analyze` — no issues.
- `flutter test` — 45 tests.

Tests:

```
test/markdown_parser_test.dart
test/list_continuation_formatter_test.dart
test/word_statistics_test.dart
test/editor/markdown_highlighter_test.dart
test/legacy_backup_test.dart
test/cloud_sync_test.dart
test/webdav_client_test.dart
test/secret_store_test.dart
```

## Structure

```
lib/
├── main.dart                 — startup, database, settings
├── app.dart                  — MaterialApp and themes
├── core/theme/               — palette, fonts, styling
├── editor/
│   ├── editor_screen.dart    — UI, sidebar, toolbars, line centering
│   ├── markdown_highlighter.dart — highlighting and focus mode
│   ├── markdown_parser.dart  — Markdown parsing, HTML, focus ranges
│   ├── list_continuation_formatter.dart — automatic list continuation
│   └── word_statistics.dart  — statistics
├── documents/                — model, repository, library, autosave, guide
├── storage/                  — SQLite, file dialogs, legacy JSON backup import
├── sync/                     — WebDAV client, cloud settings, manual sync
├── preview/                  — native preview
└── settings/                 — settings and their storage

tool/prepare_windows_links.ps1 — junctions for building without administrator rights
tool/build_windows_release.ps1 — full Windows release build cycle and dist update
benchmark/editor_benchmark_test.dart — highlight, layout, and paint measurements
ROADMAP.en.md                 — development plan up to 3.0
windows/runner/               — window (title "Перо", starts maximized), icon, and metadata
```

## Deliberately postponed

Automatic background sync, accounts, AI generation, part-of-speech highlighting, plugins, collaborative editing, and a custom low-level text engine. First, a quality writing tool.
