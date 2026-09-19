import XCTest

@MainActor
public enum NavigationBarPopper {
	/// Pops navigation until any `rootIdentifiers` element exists or no back button remains.
	public static func popTowardRoot(
		in app: XCUIApplication,
		rootIdentifiers: [String],
		maxPops: Int = 5
	) {
		let rootElements = rootIdentifiers.map { identifier in
			app.descendants(matching: .any)
				.matching(identifier: identifier)
				.firstMatch
		}

		if rootElements.contains(where: { $0.waitForExistence(timeout: 0.5) }) {
			return
		}

		// Do not use `element(boundBy: 0)` + `isHittable` in a `for … where` filter.
		// After the first pop the navigation bar may have no buttons; XCTest throws
		// "No matches found for Descendants matching type Button" instead of false.
		for _ in 0 ..< maxPops {
			let navButtons = app.navigationBars.buttons
			guard navButtons.count > 0 else { return }
			let backButton = navButtons.firstMatch
			guard backButton.exists else { return }
			backButton.tap()
			if rootElements.contains(where: { $0.waitForExistence(timeout: 0.5) }) {
				return
			}
		}
	}
}
