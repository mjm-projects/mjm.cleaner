# Guardrails

Rules that must never be broken in `mjm-projects/mjm.cleaner`. They are derived from the
repository at commit `c0697f1`: the user-facing promises in `README.md`, the code that enforces
them, the build and packaging scripts, the CI workflow, and the accepted decision records in
`docs/superpowers/decisions/`. Each rule names its evidence. Anything the repository does not
settle is listed under **Open questions** instead of being written as a rule.

## 1. Deletions and the cleanup engine

1. **Never delete without the mandatory preview and an explicit confirmation.** Step 3 must show
   the exact paths and sizes before anything is removed, and only confirmed selections may reach
   `CleanEngine`.
   Evidence: `README.md` (intro and «How it works»), `CleanerCore/Cleaning/CleanEngine.swift`.
2. **Never weaken, bypass or make configurable `PathGuard`, `DenyList` or `RootResolving`.** Every
   root and every item is validated immediately before deletion; a rejected path must fail that
   item, never fall through to a deletion.
   Evidence: `CleanerCore/Safety/PathGuard.swift`, `DenyList.swift`, `CleanEngine.clean`.
3. **Never add a cleanup rule for the app's own data or for Docker engine data.** The app's
   Application Support directory, settings, history, logs and updates stay on the deny list, as do
   Docker Desktop, `~/.docker`, `~/.orbstack` and `~/OrbStack`; Docker space is reclaimed only from
   the Docker page through the CLI.
   Evidence: `DenyList.swift`, `Settings/AppPaths.swift`, `README.md` (Warnings).
4. **Never add privilege escalation.** No `sudo`, no password prompt and no privileged helper.
   Items owned by `root` fail with an access-denied error.
   Evidence: `README.md` (Warnings).
5. **Never preselect high-risk work.** Trash, Downloads and Large files stay unselected, and
   Download and Large-file items start deselected; only the explicit «Empty Downloads» proposal
   starts its own items selected.
   Evidence: `CategoryCatalog.swift`, `README.md` (How it works).
6. **Never descend into a macOS package in Downloads, Large files or Logs.** A package is proposed
   and deleted as one item; entering it would break the app, photo library or virtual machine.
   Evidence: `README.md` (Categories), `Scanning/RuleScanner.swift`.
7. **Never ignore an invalid or unverifiable exclusion.** It must stop every rule and be explained
   in step 3; exclusions must be compared in text, in the disk spelling and through symbolic links
   as the kernel resolves them.
   Evidence: `Scanning/ExcludedFolders.swift`, `README.md` (Categories).

## 2. External tools and engines

8. **Never pass user data through a shell.** Launch executables with argument arrays through
   `ProcessRunner`/`ProcessRunning`; Docker is invoked by absolute path and every command is
   scoped with `docker --context <name>`.
   Evidence: `Platform/ProcessRunner.swift`, `Docker/DockerCli.swift`,
   `docs/superpowers/decisions/2026-10-19-registro-decisioni-docker-delete-guard.md`.
9. **Never use `docker system prune`, `docker rmi -f`/`--force`, or delete an image by tag.** Delete
   images by full ID (`sha256:…`), never start an engine, and never change the active context.
   Evidence: `README.md` (Docker), `Docker/DockerCleanExecutor.swift`.
10. **Never remove Xcode Archives.** Archives contain shipped binaries and dSYMs; only DerivedData,
    Device Support, simulated devices and runtimes are candidates.
    Evidence: `CategoryCatalog.swift`, `Xcode/XcodeFileScanner.swift`, `README.md` (Xcode).
11. **Never delete a simulator or runtime by name or alias.** Use UUID-targeted `xcrun simctl`
    commands, and never remove dependent devices automatically.
    Evidence: `Xcode/XcodeCli.swift`, `README.md` (Xcode).
12. **Never skip update verification.** An update is accepted only from the HTTPS GitHub address of
    this repository and this tag, after a SHA-256 match, the expected bundle id and version, a valid
    code signature, and both `arm64` and `x86_64` slices; the installer must keep the old bundle
    recoverable.
    Evidence: `Update/ReleaseFeed.swift`, `Update/UpdateDownloader.swift`,
    `Update/UpdateVerifier.swift`, `README.md` (Updates).
13. **Never replace the updater's ephemeral HTTP session with one that shares cookies, caches or
    credentials.**
    Evidence: `Update/HTTPClient.swift`.

## 3. Data, history and migrations

14. **Never store deleted paths in SQLite.** `history.db` holds one row per session and per
    category; the complete path list goes only to `logs/session-NNNNNN.jsonl.gz`.
    Evidence: `README.md` (History and logs), `History/HistoryStore.swift`,
    `History/SessionLogWriter.swift`.
15. **Never let log rotation delete a journal or a newer session.** The current limit is 20
    `session-NNNNNN.jsonl.gz` files, pruned by the numeric value of the name, not
    lexicographically.
    Evidence: `SessionLogWriter.swift`.
16. **Never delete, rewrite or migrate existing user data.** Settings and history are the user's
    data; the C# application's data under `~/Library/Application Support/mjm.cleaner/` is neither
    read nor migrated.
    Evidence: `README.md` (History and logs), `Settings/AppPaths.swift`.
17. **Never drop or rename an existing `history.db` table or column, and never change its meaning,
    without a new `PRAGMA user_version` and an upgrade path that preserves existing rows.**
    `schemaVersion` is 1 and `initialize()` only creates missing tables; there is no migration code.
    Evidence: `History/HistoryStore.swift`, `docs/superpowers/specs/2026-09-15-mjm-cleaner-design.md`
    (schema versioning through `PRAGMA user_version`).
18. **Never make startup depend on readable settings.** Unreadable or corrupt settings fall back to
    `CleanerSettings()`; they must not prevent launch.
    Evidence: `Settings/SettingsStore.swift`.
19. **Never keep application data outside `AppPaths`.** Release data lives under
    `~/Library/Application Support/com.mjm.cleaner/`; Debug builds use the separate
    `com.mjm.cleaner.debug` identifier and must not share that data.
    Evidence: `AppPaths.swift`, `Config/Base.xcconfig`, `Config/Debug.xcconfig`.

## 4. Secrets, signing and machine-specific data

20. **Never commit credentials, tokens, keys, certificates, provisioning profiles, a signing
    identity or a `DEVELOPMENT_TEAM`.** The app is ad hoc signed (`CODE_SIGN_IDENTITY = -`) and CI
    uses only its own `GITHUB_TOKEN`.
    Evidence: `Config/Base.xcconfig`, `.github/workflows/release-macos.yml`.
21. **Never add a Developer ID, notarization step or other signing change without an accepted
    decision.** Distribution is deliberately ad hoc signed and not notarized.
    Evidence: `README.md` (Development, Warnings), `Base.xcconfig`.
22. **Never put a real home directory, user name, checkout path or other machine-specific path into
    source, tests, fixtures or the bundle.** The packaging script rejects a bundle that names
    `/Users/<name>/`, a temporary build directory or the checkout path.
    Evidence: `Scripts/package-release.sh`, `Config/Release.xcconfig`.
23. **Never make Debug and Release share a bundle identifier or application data.**
    Evidence: `Config/Base.xcconfig`, `Config/Debug.xcconfig`.

## 5. Generated files and build output

24. **Never hand-edit the generated asset catalog `Contents.json` files.** Edit
    `Scripts/make-assets.py`, run it against `MjmCleaner/Assets.xcassets`, and commit the generated
    files. `AppIcon-1024.png` is copied separately.
    Evidence: `Scripts/make-assets.py`.
25. **Never commit ignored build or scratch output:** `.build/`, `.swiftpm/`, `DerivedData/`,
    `artifacts/`, `.superpowers/`, `xcuserdata/` and `*.xcuserstate`.
    Evidence: `.gitignore`.
26. **Never hand-add a source file under `MjmCleaner/` to `project.pbxproj`.** The app target uses
    `PBXFileSystemSynchronizedRootGroup`, so files in that folder are included automatically; add
    the file to the folder, not to build-phase entries.
    Evidence: `MjmCleaner.xcodeproj/project.pbxproj`.
27. **Never leave a test fixture unhandled: keep the `exclude:` entries in
    `MjmCleanerKit/Package.swift` aligned with the fixture folders.** The JSON fixtures are read
    through `#filePath`; an unhandled fixture becomes a warning and fails the
    `-warnings-as-errors` build.
    Evidence: `MjmCleanerKit/Package.swift`.

## 6. Tests and build quality

28. **Never merge warnings.** The package must pass `swift test -Xswiftc -warnings-as-errors`, and
    the app must build with `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` and
    `GCC_TREAT_WARNINGS_AS_ERRORS = YES`.
    Evidence: `.github/workflows/release-macos.yml`, `Config/Base.xcconfig`.
29. **Never let a test depend on the real network, a real Docker daemon, real Xcode/simulator state,
    or the user's home directory.** Use Swift Testing, the doubles under `Support/`, and
    `TemporaryDirectory` under `$TMPDIR` instead.
    Evidence: every test imports `Testing`; `Tests/CleanerCoreTests/Support/`,
    `Tests/CleanerCoreTests/Integration/`.
30. **Never add a test that asserts nothing.** Every `@Test` needs `#expect` or `#require`; the
    project's review ledger explicitly rejects assertion-free tests.
    Evidence: `docs/superpowers/decisions/` (review rubrics and mutation-testing notes).
31. **Never delete or weaken a test to make a change pass.** Fix the behavior, add a regression test,
    or record an accepted decision that changes the guarantee.
    Evidence: `docs/superpowers/decisions/` (mutation testing and review rulings).
32. **Never exercise a destructive feature against the machine you are developing on to try a
    change.** Use the Debug demo (`-MJMDemo`), the test doubles, `TemporaryDirectory`, or a
    disposable tree; never run real cache, Docker, simulator or runtime deletion while developing.
    Evidence: `README.md` (Development and Warnings), `MjmCleaner/Demo/`, the in-memory test doubles.

## 7. Protected paths

33. **Treat these paths as protected: do not modify them in an Agent Step unless the work item
    explicitly asks for it, and update the test or decision record that covers their invariant.**
    - `.github/` — the only workflow validates tags, runs tests and publishes releases.
    - `Config/Base.xcconfig`, `Config/Debug.xcconfig`, `Config/Release.xcconfig` and
      `Config/Info.plist` — identity, warnings-as-errors, universal build and local-path stripping.
    - `Scripts/package-release.sh`, `Scripts/package-release.test.sh` — the only supported release
      path and its invariants.
    - `MjmCleanerKit/Sources/CleanerCore/Safety/` — `PathGuard`, `DenyList`, canonical paths.
    - `MjmCleanerKit/Sources/CleanerCore/Update/` — digest, signature and bundle verification.
    - `MjmCleaner.xcodeproj/project.pbxproj` — the application target and shared scheme.
    - `LICENSE`.

    Evidence: the files themselves, `README.md` (Development, Warnings), and the release workflow.

## Open questions

These are not rules because the repository does not decide them.

- **Approval for protected paths.** There is no `CODEOWNERS`, branch protection or written review
  policy in the repository; rule 33 relies on the work item and the pull request.
- **History migrations.** There is no migration code and no documented procedure for moving a
  `history.db` from one schema version to another; whether a migration helper should be introduced
  is undecided.
- **Dependency policy.** `MjmCleanerKit/Package.swift` currently declares no external Swift package
  dependency (only the system `CZlib` library), but no written policy says whether one may be added.
- **Network and telemetry.** The only network client is the update checker; the repository does not
  state whether any other network access or telemetry is acceptable.
- **Localization authority.** `docs/superpowers/specs/2026-10-19-localization-design.md` proposes
  English source strings with Italian, German and Spanish translations, but the code and the three
  `Localizable.xcstrings` catalogs still use `sourceLanguage: "it"` and Italian text. Which document
  is authoritative is unresolved.
- **Bundle identifier.** `Config/Base.xcconfig` calls `com.mjm.cleaner` provisional, while the update
  feed, the release ZIP name and the Full Disk Access instructions depend on it; whether it may
  still change is undecided.
- **Formatting and linting.** There is no committed Swift formatter or linter configuration; whether
  to add one is undecided.
