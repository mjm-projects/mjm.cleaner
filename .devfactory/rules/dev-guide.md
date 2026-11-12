# Developer guide

How work is done in `mjm-projects/mjm.cleaner`. The rules below are derived from the repository at
commit `c0697f1`: its layout, `Package.swift`, the Xcode configuration, the scripts, the CI workflow,
the README and the accepted decision records in `docs/superpowers/decisions/`. Anything the
repository does not settle is listed under **Open questions**, not presented as a convention.

## 1. Repository map

| Path | What lives there |
|---|---|
| `MjmCleaner/` | The SwiftUI/AppKit application target. Domain folders: `App/`, `Cleanup/`, `Demo/`, `Docker/`, `History/`, `Settings/`, `Shell/`, `Update/`, `Xcode/`; plus `Assets.xcassets/` and `Localizable.xcstrings`. |
| `MjmCleanerKit/` | The Swift package. `CleanerCore` holds models, scanning, cleaning, safety, Docker, Xcode, update, history, settings and platform code. `CleanerFeatures` holds presentation models, navigation and environment composition. `CZlib` is the system zlib module. |
| `MjmCleanerKit/Tests/` | `CleanerCoreTests` and `CleanerFeaturesTests`, mirroring the source folders and sharing doubles in each target's `Support/`. |
| `Config/` | `Base.xcconfig`, `Debug.xcconfig`, `Release.xcconfig` and the hand-written `Info.plist`. |
| `Scripts/` | Release packaging, screenshots, asset generation, and the `.test.sh` companions that exist. |
| `docs/superpowers/` | Design specs, implementation plans, decision records, verification reports, parity material and spikes. |
| `.github/workflows/` | The single macOS release workflow. |
| `.devfactory/rules/` | `guardrails.md` and this guide; `AGENTS.md` points to both. |

The application target uses `PBXFileSystemSynchronizedRootGroup`: adding a file under
`MjmCleaner/` is enough for Xcode to build it. Package sources are discovered from
`MjmCleanerKit/Sources/<target>/`. Tests live only in the package; there is no test target for the
app.

Architecture rule: `CleanerCore` and `CleanerFeatures` must not import SwiftUI or AppKit. Views stay
in the app; page behaviour is verified through the `CleanerFeatures` models with `swift test`
(see the comment in `MjmCleanerKit/Package.swift`).

## 2. Toolchain

- macOS 15 or later.
- Xcode 27 and Swift tools 6.2 or later; the package and the app use Swift 6 language mode.
- The package declares no external Swift package dependency. It uses the system `SQLite3`,
  `CryptoKit`, `Darwin` and the local `CZlib` module.
- Debug uses bundle id `com.mjm.cleaner.debug`; Release uses `com.mjm.cleaner`. They deliberately
  have separate application data.

## 3. Build and test commands

Run these from the repository root unless stated otherwise.

```bash
# Resolve the package (also the environment's setup command)
(cd MjmCleanerKit && swift package resolve)

# Tests, as documented in the README
(cd MjmCleanerKit && swift test)

# Tests exactly as CI runs them, with warnings as errors
(cd MjmCleanerKit && swift test -Xswiftc -warnings-as-errors)

# Debug build of the app
xcodebuild -project MjmCleaner.xcodeproj -scheme MjmCleaner -configuration Debug build

# Script tests (CI runs all three)
bash Scripts/package-release.test.sh
bash Scripts/demo-xcode-preview.test.sh
bash Scripts/update-install.test.sh

# Build the distributable universal app (the only supported release path)
Scripts/package-release.sh --tag v0.1.0 --build-number 1 --output-dir artifacts

# Regenerate the asset catalog after changing Scripts/make-assets.py
python3 -I Scripts/make-assets.py MjmCleaner/Assets.xcassets

# Debug-only screenshots of the demo pages; do not use the Mac while it runs
Scripts/screenshots.sh [--size WxH] <out-dir> [page…]
```

There is no Node/npm project in this repository, so `npm test` does not exist here; `swift test` is
the test command. For a demo run, Debug builds accept `-MJMDemo <page>` and never touch the disk.

## 4. What a change should include

- Make the smallest change that resolves the work item and follow the style of the surrounding code.
- Add or update tests for behaviour changes. A bug fix needs a test that fails before the fix. A
  refactor that should not change behaviour must keep the existing tests green; do not change their
  expectations silently.
- Keep the build warning-free. CI runs `swift test -Xswiftc -warnings-as-errors`; the Xcode
  configuration also sets `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` and
  `GCC_TREAT_WARNINGS_AS_ERRORS = YES`.
- Update `README.md` when user-visible behaviour, requirements, warnings, data locations or
  commands change. The README is in English and is the user-facing reference.
- Localize user-visible text through the existing mechanism: `String(localized:bundle: .module)` in
  `CleanerCore` and `CleanerFeatures`, `LocalizedStringKey`/`Text("…")` in the app. The three
  `Localizable.xcstrings` catalogs currently use `sourceLanguage: "it"` and the source text is
  Italian; tests compare the Italian source text.
- For a feature-sized change, follow the repository's documentation flow: a dated spec under
  `docs/superpowers/specs/`, a plan under `docs/superpowers/plans/`, and a decision record under
  `docs/superpowers/decisions/`. These documents are predominantly in Italian and record the
  evidence, the decisions, the rejected alternatives and the open follow-ups.
- Do not modify protected paths unless the work item explicitly asks for it; see
  `.devfactory/rules/guardrails.md`.
- Do not commit build output or scratch files. `.build/`, `.swiftpm/`, `DerivedData/`,
  `artifacts/`, `.superpowers/` and Xcode user state are ignored.

## 5. Naming and code style

- Files are named after their primary type (`DockerClassifier.swift`, `HistoryStore.swift`);
  folders group by domain (`Safety/`, `Scanning/`, `Docker/`, `Xcode/`, `Update/`).
- Types use `UpperCamelCase`; functions, properties and enum cases use `lowerCamelCase`. Public
  API and non-obvious safety logic carry doc comments explaining the reason and the threat model.
- Test files are named `<Type>Tests.swift` and mirror the source folder. Test functions are
  descriptive lowerCamelCase sentences, often long and behaviour-focused; parameterized cases use
  `@Test(arguments:)`.
- Use `guard` and thrown errors for invalid input. The sources contain no `try!`, `as!` or
  `fatalError`; tests use `#require` for setup that must succeed. Keep that pattern.
- Use the abstractions that make the code testable: the `FileSystem` protocol instead of touching
  the disk in `CleanerCore`, `ProcessRunning`/`ProcessRunner` instead of `Process` or a shell,
  `WallClock` instead of `Date()` in models, and the CLI protocols (`DockerCommandRunning`,
  `XcodeCommandRunning`) instead of invoking tools directly.
- `CleanerCore` has no UI dependency; `CleanerFeatures` holds presentation state and returns text,
  not views. Keep view-only concerns in `MjmCleaner/`.
- Indent with four spaces and keep line width close to the surrounding file. No formatter or linter
  configuration is committed.
- Comments and decision records are predominantly in Italian; keep new comments in Italian. User-visible
  strings are Italian source text, `README.md` is English, and script output and error messages from
  the scripts are English.

## 6. Tests expected with a change

- Put tests in `MjmCleanerKit/Tests/CleanerCoreTests` or `CleanerFeaturesTests`, in the folder that
  mirrors the changed source file. Use `@testable import CleanerCore` / `@testable import
  CleanerFeatures` and Swift Testing (`import Testing`, `@Test`, `#expect`, `#require`), not XCTest.
- Prefer doubles over real resources: `InMemoryFileSystem`, the fake Docker CLI and contexts,
  fixture JSON, a fixed clock and the doubles under `Support/`. The updater's `HTTPClient` is a
  protocol so tests never use the network.
- Integration tests may use `TemporaryDirectory` (under `$TMPDIR`) or `LocalFileSystem` on a
  temporary tree. They must clean up after themselves and must never touch the user's home, the
  real Docker daemon, real Xcode state or a real network endpoint.
- A test must assert something: every `@Test` needs at least one `#expect` or `#require`. The review
  ledgers in `docs/superpowers/decisions/` explicitly reject assertion-free tests.
- Shared fixtures for Docker, Xcode and updates live in `Tests/.../Fixtures`; they are read through
  `#filePath` and excluded in `Package.swift`, so add fixtures there rather than to a bundle.
- For shell changes, keep the existing `*.test.sh` companions passing and add a case when the
  change introduces a new rule or failure mode. Run all three scripts listed in section 3.
- For UI changes there is no automated view test target. Build the app in Debug, exercise the demo
  (Debug only), and use `Scripts/screenshots.sh` when a visual check is needed. Do not use the Mac
  while the screenshot script runs.
- The project uses mutation testing as a review technique: a reviewer removes a guarantee and
  checks that at least one test fails. New safety guarantees should be written so such a test exists.
- Run the full suite, not only the touched test file, before handing the change over.

## 7. Data and file-system conventions

- Application data is defined in `AppPaths` under
  `~/Library/Application Support/com.mjm.cleaner/` (Release) or
  `~/Library/Application Support/com.mjm.cleaner.debug/` (Debug): `history.db`, `settings.json`,
  `logs/` and `updates/`.
- `history.db` stores one row per session and per category; deleted paths go to the compressed
  `logs/session-NNNNNN.jsonl.gz` files, and the latest 20 sessions are retained. Do not move path
  detail into SQLite.
- Settings are JSON with pretty-printed, sorted keys. Unreadable settings fall back to defaults;
  unreadable history leaves the History page empty. A persistence failure must never hide a cleanup
  that already happened.
- The schema version is `PRAGMA user_version = 1` and `HistoryStore.initialize()` only creates
  missing tables. Preserve existing data and do not drop or rename columns without a migration.
- Use `AppPaths` instead of assembling paths by hand, and use `PathText` for path operations. Do not
  introduce a second data directory or share Debug and Release data.

## 8. Documentation and decision records

- `README.md` is the user-facing document: what the app does, requirements, how to run it, warnings,
  data locations and the update story. Keep it in English and keep it accurate.
- `docs/superpowers/specs/` holds dated design specifications; `plans/` holds the implementation
  plan; `decisions/` holds the decision ledger for each executed piece of work; `verification/`
  holds the evidence that a release or UI checkpoint passed. Feature work in this repository
  normally has all three.
- Decision records are historical ledgers. Do not rewrite an old plan or ledger to match a later
  change; add a new dated record and note what it supersedes.
- When a change alters a user-visible behaviour, update the README in the same change. When it
  alters an accepted design decision, add a decision record rather than silently diverging.
- Keep documentation evidence-based: cite the file, test or measurement that supports a claim, and
  leave unresolved questions explicit instead of presenting a guess as a rule.

## 9. Commit and pull request conventions

The repository has no `CONTRIBUTING.md`, commit template or PR template. The observable conventions
are:

- Branches are descriptive: `feat/<slug>` and `codex/<slug>` appear in the decision records; the
  DevFactory flow uses `devfactory/issue-<number>-<hash>`.
- Work is merged with a merge commit whose subject is
  `Merge pull request #<n> from <owner>/<branch>` (visible in the repository history).
- The pull-request title is a short descriptive sentence, for example
  `Change repository URL for check update`; there is no evidence of Conventional Commits prefixes.
- Feature work is recorded in task-sized commits with the base and head SHAs noted in the decision
  ledger; keep a change focused and do not mix unrelated edits.
- The pull-request body should state what changed and how it was tested. DevFactory publishes the
  change as a pull request; an Agent Step does not commit, push or create branches itself.
- Release tags use `vMAJOR.MINOR.PATCH` and are built by CI; see section 10.

## 10. Release

- Never ship a hand-built app. `Scripts/package-release.sh` builds a universal Release
  (`arm64` + `x86_64`), copies `artifacts/mjm.cleaner.app`, creates
  `artifacts/mjm.cleaner-vX.Y.Z-macos-universal.zip`, ad hoc signs it, and verifies architectures,
  signature, the absence of local build paths and the extracted copy. It refuses to overwrite an
  existing bundle or ZIP.
- The tag supplies `MARKETING_VERSION` and the build number supplies `CURRENT_PROJECT_VERSION`; do
  not rely on the defaults in `Config/Base.xcconfig` for a release.
- CI (`.github/workflows/release-macos.yml`) validates the `vX.Y.Z` tag, runs the package tests with
  warnings as errors, runs the script tests, builds Debug, packages the universal app, and
  publishes the ZIP as a GitHub release. Changing that workflow is a protected-path change.

## Open questions

- **Commit and PR format.** No committed document specifies commit subject rules, trailers,
  sign-off, squash-versus-merge, or required reviewers; the conventions above are inferred from the
  visible history and the decision ledgers.
- **PR template and review policy.** There is no `.github/PULL_REQUEST_TEMPLATE`, `CODEOWNERS` or
  branch-protection configuration in the repository.
- **Versioning.** The policy for choosing the next `MARKETING_VERSION` and whether every merge needs
  a release is not documented; the tag is the source of the release version.
- **Dependencies.** `Package.swift` currently has no external Swift package dependency, but there is
  no written policy on adding one.
- **Localization authority.** `docs/superpowers/specs/2026-10-19-localization-design.md` proposes
  English source strings with Italian, German and Spanish translations, while the code and catalogs
  still use `sourceLanguage: "it"` and Italian text. Which document is authoritative is undecided.
- **App tests.** The app target has no test target; whether UI or view-model tests should be added
  outside the package is not decided.
- **Formatter and linter.** No Swift formatter or linter is configured; whether to adopt one is an
  open question.
- **Documentation threshold.** The repository's feature work has specs, plans and decision records,
  but it is not written whether every small change needs one or only feature-sized work does.
- **Warnings locally.** CI runs the suite with `-warnings-as-errors`; it is not stated whether every
  local test run must use the same flag, although the change should be warning-free either way.
