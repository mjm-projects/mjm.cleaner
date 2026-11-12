# Guardrails

What must never be done in this repository. These rules apply to every Agent Step. They are
constraints, not preferences: when a work item seems to require breaking one, stop and ask for an
accepted decision instead of weakening the guardrail.

Evidence comes from the repository itself: `README.md`, `AGENTS.md`, `Config/*.xcconfig`,
`.github/workflows/release-macos.yml`, the source under `MjmCleaner/` and `MjmCleanerKit/`, and the
accepted specs, plans and decision records under `docs/superpowers/`.

## Deletion and filesystem safety

- **G-01 — Delete only through a guarded engine.** Deletion of cleanup targets goes through
  `CleanEngine`; Docker deletion goes through `DockerCleanExecutor`; Xcode file deletion goes
  through `CleanEngine`, and devices/runtimes through `XcodeCleanExecutor` and UUID-targeted
  `xcrun simctl`. Do not add a second cleanup-target deletion path in a view, model or script.
  *Evidence:* `CleanerCore/Cleaning/CleanEngine.swift`, `Docker/DockerCleanExecutor.swift`,
  `Xcode/XcodeCleanExecutor.swift`, `README.md` §Warnings.
- **G-02 — Never skip or weaken path validation.** Call `PathGuard.validateRoot` once per
  distinct root before `validate`, and delete the path returned in `canonicalPathValidated`, not
  the original argument. Never carry a root verdict to an unrelated root; the engine's folded
  root key is the existing mechanism for its own spellings.
  *Evidence:* `Safety/PathGuard.swift`, `Cleaning/CleanEngine.swift`.
- **G-03 — Never make the deny list configurable.** `DenyList` and its exceptions are the last
  line of defence. Do not add UI settings, preferences or environment overrides for protected
  paths, and do not remove a path from the list without an accepted decision.
  *Evidence:* `Safety/DenyList.swift` (“Non configurabile dall'interfaccia”), `Safety/PathGuard.swift`.
- **G-04 — Never make a destructive choice the default.** Trash, Downloads and Large files stay
  high risk and are never preselected; Downloads and Large files items start deselected. The
  one-run «Empty Downloads» mode is the only documented exception.
  *Evidence:* `Categories/CategoryCatalog.swift`, `Categories/CleanupCategory.swift`,
  `Tests/CleanerCoreTests/Categories/CategoryCatalogTests.swift`, `README.md` §Categories.
- **G-05 — Never delete before the confirmation step.** Scanning is read-only and the preview
  must list exact paths and sizes before deletion. Do not add a shortcut, auto-clean, background
  clean or “clean now” action that bypasses step 3.
  *Evidence:* `README.md` §How it works, `CleanerFeatures/Cleanup/ConfirmStepModel.swift`.
- **G-06 — No privilege escalation.** Never use `sudo`, ask for a password, install a helper
  tool with elevated rights, or otherwise bypass the user's permissions. Access-denied failures
  are reported, not worked around.
  *Evidence:* `README.md` §Warnings (“No privilege elevation”), no `sudo` in the source.
- **G-07 — Never delete through a symbolic link.** Remove the link itself, not its target, and
  refuse a candidate whose ancestor is a link. Resolving a link is allowed only to judge or
  compare a destination (`PathGuard.validateRoot`, `ExcludedFolders`), never to delete through it.
  *Evidence:* `Platform/LocalFileSystem.swift`, `Safety/PathGuard.swift`, `Scanning/ExcludedFolders.swift`,
  `Tests/CleanerCoreTests/Integration/RealFileSystemCleanupTests.swift`.
- **G-08 — Never point a test or a script at real user data.** Tests use
  `InMemoryFileSystem`, `TemporaryDirectory` or `TestHome`; live cleanup is never run against
  `$HOME`, `/`, a real cache directory or a real Docker engine.
  *Evidence:* `Tests/CleanerCoreTests/Support/TemporaryDirectory.swift`,
  `Tests/CleanerFeaturesTests/Support/TestHome.swift`.

## Docker and Xcode destructive operations

- **G-09 — Never start, stop or switch a Docker engine.** The app only talks to the engine of the
  active context; a stopped daemon is reported with a Retry action. Do not add “start Docker”.
  *Evidence:* `README.md` §Docker, `Docker/DockerCleanupService.swift`, `Docker/DockerCleanExecutor.swift`.
- **G-10 — Never use broad or forced Docker deletion.** No `docker system prune`; images are
  removed by full `sha256:` ID, never by tag; never pass `-f`/`--force` to `docker rmi` or
  `docker volume rm`. `builder prune -f` is the documented build-cache exception because it only
  skips the interactive prompt.
  *Evidence:* `Docker/DockerCleanExecutor.swift` (comments and `command(_:)`), `README.md` §Docker.
- **G-11 — Never delete from the wrong Docker context.** Every analysis and deletion command must
  carry `--context <the context read at analysis start>`, and the daemon identity (ID, OS,
  version) must still match immediately before deleting. If it changed, delete nothing.
  *Evidence:* `Docker/DockerCleanExecutor.swift`, `Docker/DockerContext.swift`, decision record
  `2026-10-19-registro-decisioni-docker-delete-guard.md`.
- **G-12 — Never remove Xcode devices or runtimes implicitly.** Devices and runtimes need
  individual confirmation; dependent devices need explicit acknowledgement and are never removed
  automatically. Archives stay excluded.
  *Evidence:* `README.md` §Xcode, `Xcode/XcodeCleanExecutor.swift`, `Xcode/XcodeSelection.swift`.

## Secrets, network and updates

- **G-13 — Never commit secrets or private machine data.** No tokens, API keys, passwords,
  signing identities, provisioning profiles, `.env` files, personal paths, logs or
  `settings.json` / `history.db` contents.
  *Evidence:* the repository contains no credentials; signing is ad hoc with no team
  (`Config/Base.xcconfig`); application data lives outside the checkout (`README.md` §History and logs).
- **G-14 — Never weaken update verification.** An update is accepted only when it comes from the
  GitHub release feed over HTTPS, its SHA-256 matches the published digest, and the extracted
  bundle has the expected bundle id, version, ad hoc signature and both `arm64` and `x86_64`.
  Never install automatically; installation needs the explicit «Install and Relaunch» action.
  *Evidence:* `Update/UpdateDownloader.swift`, `Update/UpdateVerifier.swift`, `README.md` §Updates.
- **G-15 — Do not add outbound networking or third-party dependencies without a decision.** The
  only outbound feature today is the GitHub release check; there is no analytics or crash
  reporting. The package has no external SwiftPM dependencies; SQLite and zlib are system libraries.
  *Evidence:* `MjmCleanerKit/Package.swift`, `Update/HTTPClient.swift`, spec
  `2026-10-13-swift-native-port-design.md` §2 (“Nessuna dipendenza esterna”).
- **G-16 — Never drive processes through a shell string.** Pass executable and arguments as an
  array through `ProcessRunner` (or the existing `Process` launcher); never build a command with
  interpolation for `sh -c`. The bundled update script is launched by path with fixed arguments.
  *Evidence:* `Platform/ProcessRunner.swift`, `Update/UpdateInstaller.swift`.

## User data, settings, history and migrations

- **G-17 — Never read, write or migrate the old C# app data.**
  `~/Library/Application Support/mjm.cleaner/` is not this app's data; the Swift app starts from
  zero under `~/Library/Application Support/com.mjm.cleaner/` (Debug:
  `com.mjm.cleaner.debug`). No migration, import or cleanup of the old folder.
  *Evidence:* `README.md` §History and logs, spec `2026-10-13-swift-native-port-design.md` §2.
- **G-18 — Never destroy or rewrite history and settings.** `history.db` is append-only session
  history; `settings.json` falls back to defaults when unreadable. A failed history or session-log
  write is reported as a warning and never turns a successful cleanup into a failure.
  *Evidence:* `History/HistoryStore.swift`, `Settings/SettingsStore.swift`,
  `CleanerFeatures/Cleanup/DoneStepModel.swift`, `README.md` §History and logs.
- **G-19 — Never store per-item paths in SQLite.** Deleted paths belong only in the compressed
  `logs/session-NNNNNN.jsonl.gz` files, with the 20-session retention. Do not add a per-item table,
  lower the retention, or write uncompressed logs without an accepted decision.
  *Evidence:* `History/HistoryStore.swift`, `History/SessionLogWriter.swift`, `README.md` §History and logs.
- **G-20 — Do not change the SQLite schema without a versioned migration.** The current schema is
  `PRAGMA user_version = 1` with `CREATE TABLE IF NOT EXISTS`; never drop user tables or rewrite
  an existing `history.db` in place. There is no migration mechanism today, so a schema change is
  an open question for the Project, not an implementation detail.
  *Evidence:* `History/HistoryStore.swift` (`schemaVersion`, `initialize`).

## Generated files, build output and protected paths

- **G-21 — Never hand-edit generated asset catalog JSON.** `MjmCleaner/Assets.xcassets/**/Contents.json`
  is generated by `Scripts/make-assets.py`; edit the script and regenerate, then commit the
  generated files.
  *Evidence:* `Scripts/make-assets.py` header (“I file Contents.json generati sono quelli da committare”).
- **G-22 — Never commit build output or local state.** Keep out
  `MjmCleanerKit/.build/`, `.swiftpm/`, `DerivedData/`, `xcuserdata/`, `*.xcuserstate`,
  `artifacts/`, `.DS_Store`, `.superpowers/`, `.idea/` and `.vscode/`.
  *Evidence:* `.gitignore`.
- **G-23 — Keep the app's configuration hand-written.** `GENERATE_INFOPLIST_FILE = NO` and
  `Config/Info.plist` are deliberate; do not switch to a generated plist. Do not change bundle
  identifiers, version, code-signing identity or the ad hoc signing model without an accepted
  decision.
  *Evidence:* `Config/Base.xcconfig`, `Config/Info.plist`, `Config/Debug.xcconfig`,
  spec `2026-10-13-swift-native-port-design.md` §4.4 and §10.1.
- **G-24 — Treat `.github/` as protected.** Do not edit workflows, add release jobs, create tags
  or publish releases unless the work item explicitly targets the release process. The current
  workflow is the only CI path.
  *Evidence:* `.github/workflows/release-macos.yml`; the Step rules forbid changing `.github/`.
- **G-25 — Do not rewrite historical documents.** `docs/superpowers/plans/`, `specs/` and
  `decisions/` are records of what was decided and executed. Add a new spec, plan or decision
  record instead of editing an old one to match new behaviour.
  *Evidence:* decision records refer to historical plans as untouchable (for example
  `2026-10-20-registro-decisioni-confirmation-containment.md`, “documento storico, non si tocca”).

## Working tree and publishing

- **G-26 — Never discard someone else's work.** Do not run `git reset`, `git clean`, `git stash`
  or `git checkout --` on the main checkout, and do not delete untracked files you did not create.
  Stage explicit paths only; never `git add -A`, `git add .` or a whole directory.
  *Evidence:* historical Global Constraints in
  `docs/superpowers/plans/2026-10-19-large-files-exclusions.md` and
  `2026-10-16-swift-port-5-handoff.md`.
- **G-27 — Never publish without an explicit instruction.** Do not push to `main`, force-push,
  rewrite published history, create branches/tags, or publish a release. DevFactory publishes the
  change as a pull request; commit only when the Step asks for it.
  *Evidence:* the repository's only visible history entry is a merged pull request
  (`.git` log), and the DevFactory Step rules say not to commit, push or branch.
