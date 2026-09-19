# AsyncSharedTestingKit (ASTK)

**AsyncSharedTestingKit** is the full name of this Swift package. The GitHub repository and SPM checkout folder are shortened to [**astk**](https://github.com/illescasDaniel/astk); library products keep the `ASTK` prefix (`ASTK`, `ASTKApp`, `ASTKXCTest`).

---

## What is ASTK?

ASTK is a **shared-process UI testing framework** for iOS. It lets XCUITest suites **launch your app once** and then **swap test scenarios at runtime** — without cold-launching between every test case.

### The problem

Classic UI tests call `XCUIApplication.launch()` per test (or per scenario). That is correct, but slow: each launch pays the full startup cost (process creation, SwiftUI tree build, initial network/cache work). A suite of 20 tests can spend most of its time launching, not asserting.

`launchEnvironment` is fixed at launch time. If you need different stub data, feature flags, or navigation starting points per test, the usual workaround is **relaunch with different env vars** — which multiplies the cost.

### What ASTK does instead

ASTK runs the app in **shared-process mode**:

1. **Launch once** with `UITESTING=1` in the launch environment.
2. For each test, **open a DEBUG-only custom URL scheme** (`myapp-uitest://apply?config=…`) carrying a **base64url-encoded JSON** payload.
3. The app **decodes the scenario**, resets navigation, swaps stubs/overrides, and bumps a **session generation** counter.
4. SwiftUI recreates the root subtree (`.id(generation)`) so `@State` ViewModels and `.task` loaders run fresh — as if the app had relaunched.
5. The test **waits for a ready marker** (`uitest-ready-{N}`) before querying elements.

The result: one process, many scenarios, much faster suites — while keeping tests isolated at the UI level.

### What ASTK is *not*

- **Not a replacement for XCUITest** — it builds on top of it (page objects, async waits, launch helpers).
- **Not for Release builds** — the deep-link transport, session shell, and URL scheme registration are **DEBUG-only**. Ship them only in Debug configuration (see below).
- **Not parallel-safe** — one app instance per simulator; disable parallel UI tests in your test plan.

---

## Products

ASTK splits into three libraries so **XCTest never links into your app target**:

| Product | Import | Link from | Purpose |
|---------|--------|-----------|---------|
| **ASTK** | `import ASTK` | App kit + UI tests (via other products) | Settings, URL transport, ready marker, session host, protocols |
| **ASTKApp** | `import ASTKApp` | **DEBUG app only** | Session coordinator, optional `UITestSessionView` shell |
| **ASTKXCTest** | `import ASTKXCTest` | UI test target only | Async page objects, `SharedProcessLauncher`, navigation popper |

Your app keeps **fixtures, accessibility IDs, and stub use cases** in its own test kit — ASTK stays generic.

---

## Installation

Add the package in Xcode (**File → Add Package Dependencies**) or in `Package.swift` using the **astk** repo URL. Xcode resolves it as the **AsyncSharedTestingKit** package:

```swift
.package(url: "https://github.com/illescasDaniel/astk", from: "0.1.0")
```

When referencing products from another local package:

```swift
.product(name: "ASTK", package: "AsyncSharedTestingKit")
```

Link **`ASTKApp`** from your DEBUG app target and **`ASTKXCTest`** from your UI test target.

---

## Quick start

### 1. Register a URL scheme — **DEBUG builds only**

Shared-process mode delivers scenarios via a custom URL (`myapp-uitest://apply?config=…`). iOS requires the scheme in **Info.plist** — but **must not ship in Release**: it is a test backdoor that can reconfigure app state at runtime.

**Do not** add `CFBundleURLTypes` to your main Release Info.plist.

Use a **Debug-only plist** and point the Debug build configuration at it:

**`MyApp/Info-Debug.plist`** (Debug configuration only):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>myapp.uitest</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>myapp-uitest</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

In Xcode build settings for your app target:

| Configuration | `INFOPLIST_FILE` |
|---------------|------------------|
| **Debug** | `MyApp/Info-Debug.plist` (merged with generated keys) |
| **Release** | *(unset — use `GENERATE_INFOPLIST_FILE` only)* |

Also gate **all** ASTK app-side wiring with `#if DEBUG`: session shell, `onOpenURL`, scenario host, and `UITestNavigationResetting` conformance. UI tests already run against the Debug build of the app.

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
#if DEBUG
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
#endif
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

---

## GamesLibrary example

[GamesLibrary](https://github.com/illescasDaniel/GamesLibrary) is the reference host app.

### DEBUG-only URL scheme

Scheme constant:

```swift
public enum GamesLibraryUITestTransport {
	public static let deepLinkScheme = "gameslibrary-uitest"
}
```

Registered in **`GamesLibrary/Info-Debug.plist`** — linked only from the **Debug** build configuration (`INFOPLIST_FILE = GamesLibrary/Info-Debug.plist`). Release builds omit the scheme entirely.

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

### DEBUG app session shell

```swift
#if DEBUG
import ASTK
import ASTKApp

struct UITestAppContent: View {
	@State private var coordinator: AppCoordinator
	@State private var scenarioHost: UITestScenarioHost
	@State private var uiTestSessionGeneration = 0
	@State private var sessionCoordinator: UITestSessionCoordinator<UITestConfiguration>

	var body: some View {
		// … AppRootView.id(generation), ready marker, onOpenURL …
	}
}
#endif
```

Navigation reset before each apply:

```swift
#if DEBUG
import ASTK

extension AppCoordinator: UITestNavigationResetting {}
#endif
```

### UI test launcher

```swift
@MainActor
enum AppLauncher {
	private static let launcher = SharedProcessLauncher<UITestConfiguration, GamesListPage>(
		settings: UITestSessionSettings(deepLinkScheme: GamesLibraryUITestTransport.deepLinkScheme),
		makeRootPage: GamesListPage.init,
		prepareForApply: { app in
			NavigationBarPopper.popTowardRoot(in: app, rootIdentifiers: [/* root IDs */])
		}
	)

	static func apply(configuration: UITestConfiguration = .default) async throws -> GamesListPage {
		try await launcher.apply(configuration: configuration)
	}
}
```

---

## Async page object helpers

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

---

## Constraints

- **Serial test plan only** — one app instance per simulator; disable parallel UI tests.
- **DEBUG only** — URL scheme (`Info-Debug.plist`), deep-link handler, session shell, ready marker, and `ASTKApp` linkage must not ship in Release.
- **Legacy path** — launch with `UITEST_CONFIG` JSON in `launchEnvironment` (without `UITESTING=1`) still works for one-shot launches via `UITestProcessInfo.initialConfiguration`.

---

## Package tests

```bash
cd astk && swift test
```

XCUITest wait/scroll behavior is validated by host-app UI tests; ASTK unit tests cover transport, process-info, and session host logic without a simulator host.
