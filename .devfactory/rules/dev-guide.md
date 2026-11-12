# Developer guide

How work is done in `mjm.cleaner`, for every Agent Step. `guardrails.md` lists what must never be
done; this file describes the shape of a change, the commands that prove it, and the conventions to
follow.

The repository is a macOS cleanup app written in Swift 6 with SwiftUI and Observation. The
behaviour lives in a local Swift package so it can be tested without launching the app.

## 1. Structure

```
MjmCleaner.xcodeproj/        Xcode project and the MjmCleaner scheme
Config/                      hand-written Info.plist and xcconfig files (identity, signing, version)
MjmCleaner/                  app target: SwiftUI views and AppKit adapters
MjmCleanerKit/               local Swift package (Swift tools 6.2, macOS 15+)
  Sources/CleanerCore/       domain logic: Categories, Cleaning, Scanning, Safety, History,
                             Settings, Docker, Xcode, Update, Platform
  Sources/CleanerFeatures/   presentation models and composition: Cleanup, Docker, Xcode,
                             History, Settings, Shell, Update, Environment, Support
  Sources/CZlib/             system-library module map for zlib
  Tests/CleanerCoreTests/    Swift Testing suites for the Core
  Tests/CleanerFeaturesTests/ Swift Testing suites for the Features layer
Scripts/                     packaging, screenshots, asset generation and script tests
docs/superpowers/            historical specs, plans, decision records and verification reports
.devfactory/rules/           the Project rules (this file and guardrails.md)
```

- **`CleanerCore`** must not import SwiftUI or AppKit and must not know `CleanerFeatures`.
- **`CleanerFeatures`** must not import SwiftUI. It holds `@MainActor @Observable` presentation
  models, navigation, the navigation lock and `AppEnvironment`. UI actions are expressed as
  protocols implemented by the app (`FolderPicking`, `AppearanceApplying`, …).
- **The app target** contains only SwiftUI views, AppKit adapters (`NSOpenPanel`, `NSApp.appearance`)
  and the `@main` entry point. Behaviour that can be tested belongs in the package.
- **Composition is manual.** `AppEnvironment` builds the object graph; there is no DI container.
  New services are protocols in the Core and are passed through `AppEnvironment`.
- **No external dependencies.** SQLite and zlib are system libraries; everything else is code in
  this repository.

*Evidence:* `MjmCleanerKit/Package.swift`, spec `2026-10-13-swift-native-port-design.md` §2, §4.1
and §4.3, `CleanerFeatures/Environment/AppEnvironment.swift`.

## 2. Build and test commands

Run commands from the repository root.

```bash
# Setup (the environment's setup command)
(cd MjmCleanerKit && swift package resolve)

# Full test suite (the required check)
(cd MjmCleanerKit && swift test)

# Full suite with the CI warning gate
(cd MjmCleanerKit && swift test -Xswiftc -warnings-as-errors)

# One suite or one test while iterating
(cd MjmCleanerKit && swift test --filter ConfirmStepModelTests -Xswiftc -warnings-as-errors)

# Compile the package and its tests without running them
(cd MjmCleanerKit && swift build --build-tests -Xswiftc -warnings-as-errors)

# Build the macOS app in Debug
xcodebuild -project MjmCleaner.xcodeproj -scheme MjmCleaner -configuration Debug build

# Script tests (all three run in CI)
bash Scripts/package-release.test.sh
bash Scripts/demo-xcode-preview.test.sh
bash Scripts/update-install.test.sh
```

- Use `swift test`, not `npm test`: there is no Node project, `package.json` or npm test script.
  `.devfactory/environment.json` also declares `cd MjmCleanerKit && swift test` as the test command.
- A green run ends with `Test run with … passed`; do not rely on a hard-coded test count. Treat any
  failure or new warning as a blocker; the release workflow compiles with `-warnings-as-errors` and
  `SWIFT_TREAT_WARNINGS_AS_ERRORS = YES`.
- Run the Debug app build when a change touches the app target, Xcode project settings, assets or
  resources. Package-only changes normally need only the Swift suite.
- Run the matching `Scripts/*.test.sh` when changing a script. Packaging changes also need
  `Scripts/package-release.sh --tag vX.Y.Z --build-number N --output-dir artifacts` (it refuses to
  overwrite an existing bundle or ZIP).
- CI is `.github/workflows/release-macos.yml`; it runs only for `v*` tags or a manual dispatch. There
  is no pull-request CI, so run the local gate before handing off.

*Evidence:* `README.md` §Development, `.devfactory/environment.json`,
`.github/workflows/release-macos.yml`, `Config/Base.xcconfig`.

## 3. Making a change

1. **Put behaviour in the right layer.** Domain rules go in `CleanerCore`; navigation and page
   state go in `CleanerFeatures`; only rendering and platform adapters go in `MjmCleaner`.
2. **Use the existing seams.** New filesystem, clock, process or network behaviour should depend on
   the protocols (`FileSystem`, `WallClock`, `ProcessRunning`, `HTTPClient`, the Docker/Xcode CLI
   protocols) so it can be tested with doubles. Core code uses `FileManager`, `Process` and
   `URLSession` only in the existing platform/update code that deliberately works on real disk or
   the network.
3. **Keep comments and security rationale.** Security-sensitive code (`PathGuard`, `DenyList`,
   `CanonicalPath`, `RuleScanner`, `CleanEngine`) carries comments explaining the rule and the
   failure it prevents. Preserve them and add the same kind of explanation for a new guard.
4. **Update user-facing documentation.** A change to visible behaviour updates `README.md` in the
   same change. Historical documents under `docs/superpowers/` are not edited; add a new spec, plan
   or decision record when a decision is needed.
5. **Add strings the existing way.** User-facing text in the package goes through
   `String(localized: "...", bundle: .module)`; SwiftUI text uses the normal localized keys. The
   current source language is Italian (`defaultLocalization: "it"`, `CFBundleDevelopmentRegion: it`).
6. **Do not change generated output by hand.** Regenerate asset catalogs with
   `python3 -I Scripts/make-assets.py MjmCleaner/Assets.xcassets`.
7. **Do not launch the app, automate the UI or take screenshots while the user is working.** For UI
   work, build Debug and read the code; screenshots with `-MJMDemo` and `Scripts/screenshots.sh`
   require the user's explicit consent and a free Mac.

*Evidence:* `CleanerFeatures/Environment/AppEnvironment.swift`,
`CleanerCore/Platform/ProcessRunner.swift`, `CleanerCore/Update/HTTPClient.swift`,
`Scripts/make-assets.py`, plans `2026-10-19-large-files-exclusions.md` and
`2026-10-20-confirmation-containment.md` (Global Constraints), `README.md` §Development.

## 4. Tests expected with a change

- **Every behaviour change gets a test** in the matching target
  (`CleanerCoreTests` or `CleanerFeaturesTests`). Bug fixes get a test that fails before the fix and
  passes after it. A change with no test is acceptable only for documentation, rules or a pure
  comment/formatting edit, and still needs the full suite to pass.
- **Use Swift Testing, not XCTest.** Tests are `struct` or `final class` suites with
  `import Testing`, `@Test func`, `#expect` and `#require`. Do not add `XCTestCase` or `import XCTest`.
- **No assertion-free tests.** Every `@Test` must assert a result, throw on an unmet precondition
  with `#require`, or record an issue. Test names are lowerCamelCase sentences describing the
  behaviour (`allowsItemInsideDeclaredRoot`, `deniedPathDoesNotReachTheEngine`).
- **Prefer real behaviour over mock verification.** Use `InMemoryFileSystem` for fast domain tests,
  `ForwardingFileSystem` and the fault decorators for failures, `FakeLinkInspector` for links, and
  `TemporaryDirectory`/`TestHome` for integration tests on real APFS (symlinks, permissions,
  recursive deletion, case folding). JSON fixtures are read through `#filePath` as the existing
  Docker/Xcode/update tests do.
- **Cover the negative case.** For safety, scanning, deletion, Docker and Xcode rules, add the
  refusal case as well as the allowed case. For a new guard, verify the test fails when the guard is
  removed (the Project's review process uses mutations for this).
- **App target:** there is no app test target. Put testable page behaviour in `CleanerFeatures` and
  test it there; use the `Scripts/*.test.sh` tests for script behaviour. A UI-only change is
  verified by the Debug build and, with consent, a demo screenshot.
- **Run the full suite** (`swift test -Xswiftc -warnings-as-errors`) and the matching build/script
  test before considering the work done. Report the command and the result in the pull request.

*Evidence:* `MjmCleanerKit/Package.swift` (test targets, excluded fixtures),
`Tests/CleanerCoreTests/Support/`, `Tests/CleanerFeaturesTests/Support/`,
`.github/workflows/release-macos.yml`, `Scripts/*.test.sh`.

## 5. Naming and style

- **Files and types:** one main type per file; the file is named after the type in
  `UpperCamelCase.swift` (`PathGuard.swift`, `DockerCleanExecutor.swift`,
  `ChooseStepModel.swift`). Test files end in `Tests.swift` and usually match the type they cover.
- **Swift names:** `UpperCamelCase` for types and protocols, `lowerCamelCase` for properties,
  methods and arguments. Protocols describe a capability (`PathGuarding`, `CleanPerforming`,
  `HistoryStoring`, `FolderPicking`, `Navigating`). Test doubles are named `Fake…`, `InMemory…`,
  `Forwarding…`, `…Spy` or `…FileSystem`, and live in the test target's `Support/` folder or next to
  the suite that uses them.
- **Access control:** package API that another module consumes is explicitly `public`; everything
  else stays internal. Do not widen access just to make a test compile; use `@testable import`.
- **Language:** code identifiers, type names, test names and `README.md` are in English. Source and
  test comments, doc comments and the current user-facing strings are in Italian. Keep that
  mixture; do not translate an existing file as a side effect.
- **Safety comments:** comments on `PathGuard`, `DenyList`, `CanonicalPath`, `RuleScanner` and
  `CleanEngine` explain why a check exists, not what the next line does. Preserve that style.
- **Formatting:** follow the surrounding file (4-space indentation, no force-unwrapping in new
  production code, no `try!`/`as!`, no unchecked index access). The only known force unwrap is the
  compile-time URL literal in `CleanerFeatures/Support/SupportLinks.swift`; do not add more.

*Evidence:* the source tree layout, `CleanerCore/Safety/*`, `CleanerFeatures/Support/SupportLinks.swift`,
and the Global Constraints in `docs/superpowers/plans/2026-10-19-large-files-exclusions.md`
(“Vietati `!` di forced unwrap, `try!`, `as!` e accessi per indice non verificati”).

## 6. Commit and pull request conventions

- **Commits:** use Conventional Commits with an optional scope:
  `feat: …`, `fix: …`, `docs: …`, `test: …`, `chore: …`, or `feat(swift): …`,
  `fix(swift): …`, `docs(swift): …` as the historical plans do. Use an imperative, lower-case
  summary without a trailing period. One logical change per commit; keep unrelated refactors out.
- **Staging:** stage explicit paths only. Never commit `.build/`, `DerivedData/`, `artifacts/`,
  `xcuserdata/`, local settings or generated logs.
- **Branches:** use a descriptive branch. Historical work used `feat/<topic>` (for example
  `feat/large-files-exclusions`); DevFactory uses `devfactory/issue-<number>-<hash>`. Never commit
  directly to `main`, never force-push and never rewrite published history.
- **Pull requests:** one focused PR per issue/change. Describe what changed, why, which tests or
  builds were run, and any manual/UI check that could not be performed. Link the issue, list open
  questions, and call out anything a reviewer must verify on a Mac. Do not include generated
  binaries or local paths. DevFactory publishes the PR; an Agent Step does not push or merge.
- **Release work:** tags are `vMAJOR.MINOR.PATCH`; packaging is done with
  `Scripts/package-release.sh`. Do not create tags or publish releases as part of a normal change.

*Evidence:* commit subjects in the historical plans (`feat: add one-run full Downloads category`,
`fix(swift): isolate the debug app identity`, `docs(swift): verify the app screens…`), the merge
commit in `.git` (`Merge pull request #7 …`), `Scripts/package-release.sh`, and the Step rule that
DevFactory publishes the change.

## 7. Open questions

These are not rules yet, because the repository does not settle them. Resolve them with a Project
decision before writing a new rule:

1. **Localization.** `docs/superpowers/specs/2026-10-19-localization-design.md` proposes English
   source keys, four languages and populated String Catalogs, but the repository still has
   `defaultLocalization: "it"`, `CFBundleDevelopmentRegion = it`, Italian literals and three empty
   catalogs. Which policy applies to new strings?
2. **SQLite migrations.** `HistoryStore` has `PRAGMA user_version = 1` and no migration code. How
   should a future schema change migrate an existing `history.db` without losing sessions?
3. **PR and branch policy.** The repository has no `CONTRIBUTING.md`, PR template or documented
   review rules. The historical plans require a `Co-Authored-By: Claude 5.5` trailer; whether that
   applies to all current commits is not visible from the truncated git history.
4. **CI coverage.** The only workflow runs on release tags or manual dispatch, so pull requests have
   no CI. Should the local `swift test -Xswiftc -warnings-as-errors` gate remain the only
   requirement, or should PR CI be added?
5. **Forced unwrap exception.** `SupportLinks.buyMeACoffee` uses `URL(string:)!`. The plans forbid
   force unwraps; whether to remove this last literal or keep it as a documented compile-time
   constant is undecided.
6. **Xcode project edits.** `MjmCleaner.xcodeproj/project.pbxproj` is committed and hand-maintained.
   There is no documented policy for regenerating it or for adding files; follow the surrounding
   minimal diff until a decision exists.
