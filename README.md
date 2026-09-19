# AsyncSharedTestingKit (ASTK)

**AsyncSharedTestingKit** is the full name of this Swift package. The GitHub repository and SPM checkout folder are shortened to [**astk**](https://github.com/illescasDaniel/astk); library products keep the `ASTK` prefix (`ASTK`, `ASTKApp`, `ASTKXCTest`).

Shared-process UI testing for iOS: **launch once**, apply **Codable scenarios at runtime**, recreate SwiftUI root state, and drive tests with an **async Page Object Model**.

Large XCUITest suites should not cold-launch the app per test. ASTK separates three concerns so XCTest never links into your app target:

| Product | Import | Link from | Purpose |
|---------|--------|-----------|---------|
| **ASTK** | `import ASTK` | App (via ASTKApp) and UI tests (via ASTKXCTest) | Settings, URL transport, ready marker, session host, protocols |
| **ASTKApp** | `import ASTKApp` | DEBUG app only | SwiftUI session shell (`.id` recreate + ready marker) |
| **ASTKXCTest** | `import ASTKXCTest` | UI test target only | Async POM helpers, `SharedProcessLauncher`, navigation popper |

## Installation

Add the package in Xcode (**File → Add Package Dependencies**) or in `Package.swift` using the **astk** repo URL. Xcode resolves it as the **AsyncSharedTestingKit** package:

```swift
.package(url: "https://github.com/illescasDaniel/astk", from: "0.1.0")
```

When referencing products from another local package, use the Swift package identity `AsyncSharedTestingKit` (or `astk`, depending on your `Package.swift` resolver):

```swift
.product(name: "ASTK", package: "AsyncSharedTestingKit")
```

Link **`ASTKApp`** from your DEBUG app target and **`ASTKXCTest`** from your UI test target. Shared types (`UITestConfiguration`, transport scheme) can live in a small app-specific kit that depends on **`ASTK`**.

## Why shared-process mode?

`launchEnvironment` is fixed at `XCUIApplication.launch()`. Relaunching per scenario is correct but slow. Shared-process mode:

1. Launches once with `UITESTING=1`
2. Applies each scenario via a DEBUG deep link (`myapp-uitest://apply?config=<base64url JSON>`)
3. Resets navigation, replaces stubs, bumps a session generation
4. Recreates root SwiftUI (`.id(generation)`) so `@State` ViewModels reload
5. Waits for an invisible ready marker (`uitest-ready-{N}`) before querying elements

## Quick start

### 1. Register a URL scheme (Info.plist)

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>myapp-uitest</string>
    </array>
  </dict>
</array>
```

### 2. Define your scenario payload (app + UI tests)

Keep fixtures and screen IDs in your app — ASTK stays generic:

```swift
struct MyUITestConfiguration: Codable {
  var userLoggedIn: Bool
  var seedItems: [String]
}
```

### 3. DEBUG app: scenario host + session shell

```swift
import ASTK
import ASTKApp

@MainActor
@Observable
final class MyScenarioHost: UITestScenarioApplying {
  typealias Configuration = MyUITestConfiguration
  private(set) var sessionGeneration = 0

  func apply(_ configuration: MyUITestConfiguration) {
    // Replace stubs / overrides for this scenario
    sessionGeneration += 1
  }
}

let settings = UITestSessionSettings(deepLinkScheme: "myapp-uitest")
let coordinator = UITestSessionCoordinator<MyUITestConfiguration>(settings: settings)

MyRootView()
  .uiTestSession(
    host: scenarioHost,
    navigationResetter: appCoordinator,
    coordinator: coordinator,
    uiTestSessionGeneration: $uiTestSessionGeneration
  )
  .onOpenURL { coordinator.handleOpenURL($0) }
```

If a complex app hierarchy hits a Swift generic-`View` demangle crash with `UITestSessionView`, inline the same shell (`.id(generation)`, ready marker, `onChange(of: host.sessionGeneration)`, wire coordinator on appear) — see the GamesLibrary example below.

Implement `UITestNavigationResetting` on your coordinator to clear `NavigationPath` before each apply.

**Important:** Root ViewModels should live in `@State` on the recreated subtree so `.id(sessionGeneration)` triggers a fresh `.task` load.

### 4. UI tests: launcher + page objects

```swift
import ASTK
import ASTKXCTest

@MainActor
struct HomePage: PageObject {
  let app: XCUIApplication

  var welcomeBanner: XCUIElement {
    get async throws {
      try await app.waitForElementAsync(matching: "home-welcome")
    }
  }
}

let settings = UITestSessionSettings(deepLinkScheme: "myapp-uitest")
let launcher = SharedProcessLauncher<MyUITestConfiguration, HomePage>(
  settings: settings,
  makeRootPage: HomePage.init,
  prepareForApply: { app in
    NavigationBarPopper.popTowardRoot(in: app, rootIdentifiers: ["home-screen"])
  }
)

func testWelcomeVisible() async throws {
  let home = try await launcher.apply(configuration: .init(userLoggedIn: true, seedItems: ["A"]))
  let banner = try await home.welcomeBanner
  try await banner.requireAsync(identifier: "home-welcome", checks: [.visible()], in: home.app)
}
```

Open apply URLs with **`XCUIDevice.shared.system.open(url)`**, not `app.open(url)` — after in-app navigation, `XCUIApplication.open` often fails to deliver the URL.

## GamesLibrary example

[GamesLibrary](https://github.com/illescasDaniel/GamesLibrary) is the reference host app. Add ASTK as a remote package, then wire app-specific types in a small `UITestKit` module.

### Deep link scheme

```swift
public enum GamesLibraryUITestTransport {
  public static let deepLinkScheme = "gameslibrary-uitest"
}
```

Register `gameslibrary-uitest` in Info.plist (`CFBundleURLSchemes`).

### Scenario host (mutable stubs + session generation)

```swift
import ASTK
import Observation

@MainActor
@Observable
public final class UITestScenarioHost: UITestScenarioApplying {
  public typealias Configuration = UITestConfiguration
  public private(set) var sessionGeneration = 0

  public let searchGamesUseCase = StubSearchGamesUseCase()
  public let getGameDetailsUseCase = StubGetGameDetailsUseCase()

  public func apply(_ configuration: UITestConfiguration) {
    let stubs = UITestSupport.makeStubTables(from: configuration)
    searchGamesUseCase.apply(responses: stubs.searchResponses)
    getGameDetailsUseCase.apply(responses: stubs.detailsResponses)
    sessionGeneration += 1
  }
}
```

### DEBUG app session shell (inline when `UITestSessionView` demangles poorly)

```swift
import ASTK
import ASTKApp

struct UITestAppContent: View {
  @State private var coordinator: AppCoordinator
  @State private var scenarioHost: UITestScenarioHost
  @State private var uiTestSessionGeneration = 0
  @State private var sessionCoordinator: UITestSessionCoordinator<UITestConfiguration>

  var body: some View {
    @Bindable var coordinator = coordinator
    @Bindable var scenarioHost = scenarioHost

    ZStack(alignment: .topLeading) {
      AppRootView(coordinator: coordinator)
        .id(uiTestSessionGeneration)
      if uiTestSessionGeneration > 0 {
        Color.clear
          .frame(width: 1, height: 1)
          .accessibilityElement()
          .accessibilityIdentifier(
            UITestReadyMarker.identifier(sessionGeneration: uiTestSessionGeneration)
          )
          .allowsHitTesting(false)
      }
    }
    .onAppear { wireSessionRuntime(scenarioHost: scenarioHost, coordinator: coordinator) }
    .onChange(of: scenarioHost.sessionGeneration) { _, generation in
      uiTestSessionGeneration = generation
    }
    .onOpenURL { sessionCoordinator.handleOpenURL($0) }
  }
}
```

Navigation reset before each apply:

```swift
#if DEBUG
import ASTK

extension AppCoordinator: UITestNavigationResetting {}
#endif
```

### UI test launcher + async page object

```swift
import ASTK
import ASTKXCTest

@MainActor
enum AppLauncher {
  private static let settings = UITestSessionSettings(
    deepLinkScheme: GamesLibraryUITestTransport.deepLinkScheme
  )

  private static let launcher = SharedProcessLauncher<UITestConfiguration, GamesListPage>(
    settings: settings,
    makeRootPage: GamesListPage.init,
    prepareForApply: { app in
      NavigationBarPopper.popTowardRoot(
        in: app,
        rootIdentifiers: [
          AccessibilityIdentifier.GamesList.screen,
          AccessibilityIdentifier.GamesList.emptyState,
        ]
      )
    }
  )

  static func apply(configuration: UITestConfiguration = .default) async throws -> GamesListPage {
    try await launcher.apply(configuration: configuration)
  }
}
```

Example test:

```swift
@MainActor
func testGivenGamesListWhenLaunchedThenShowsTitle() async throws {
  let list = try await AppLauncher.apply()
  let screen = try await list.screen
  try await screen.requireAsync(
    identifier: AccessibilityIdentifier.GamesList.screen,
    checks: [.visible()],
    in: list.app
  )
}
```

## Async POM helpers

Page accessors should be `get async throws` and wait for **existence only**. Stronger checks are opt-in:

```swift
try await element.requireAsync(
  identifier: "game-row-name",
  checks: [.visible(), .nonEmptyText()],
  in: app
)
```

| `ElementRequirement` | Meaning |
|--------------------|---------|
| `.exists()` / `.exists(false)` | In hierarchy / gone |
| `.visible()` / `.visible(false)` | On screen / off screen |
| `.visible(scroll: true)` | Scroll into view, then on-screen |
| `.tappable()` / `.enabled()` | Hittable / enabled |
| `.nonEmptyText()` | Label or value is non-empty |

Nested row IDs: conform subviews to `NestedPageObject` and query via `root.descendants(matching:)`.

## Constraints

- **Serial test plan only** — one app instance per simulator; disable parallel UI tests.
- **DEBUG only** — deep link scheme and ready marker are not for Release builds.
- **Legacy path** — launch with `UITEST_CONFIG` JSON in `launchEnvironment` (without `UITESTING=1`) still works for one-shot launches via `UITestProcessInfo.initialConfiguration`.

## Package tests

```bash
cd astk && swift test
```

XCUITest wait/scroll behavior is validated by host-app UI tests; ASTK unit tests cover transport, process-info, and session host logic without a simulator host.
