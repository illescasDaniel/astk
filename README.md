# AsyncSharedTestingKit (ASTK)

Shared-process UI testing for iOS: **launch once**, apply **Codable scenarios at runtime**, recreate SwiftUI root state, and drive tests with an **async Page Object Model**.

Large XCUITest suites should not cold-launch the app per test. ASTK separates three concerns so XCTest never links into your app target:

| Product | Import | Link from | Purpose |
|---------|--------|-----------|---------|
| **ASTK** | `import ASTK` | App (via ASTKApp) and UI tests (via ASTKXCTest) | Settings, URL transport, ready marker, session host, protocols |
| **ASTKApp** | `import ASTKApp` | DEBUG app only | SwiftUI session shell (`.id` recreate + ready marker) |
| **ASTKXCTest** | `import ASTKXCTest` | UI test target only | Async POM helpers, `SharedProcessLauncher`, navigation popper |

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

If a complex app hierarchy hits a Swift generic-`View` demangle crash with `UITestSessionView`, inline the same shell (`.id(generation)`, ready marker, `onChange(of: host.sessionGeneration)`, wire coordinator on appear) — see `GamesLibrary/App/UITest/UITestAppContent.swift`.

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
cd AsyncSharedTestingKit && swift test
```

XCUITest wait/scroll behavior is validated by host-app UI tests; ASTK unit tests cover transport, process-info, and session host logic without a simulator host.
