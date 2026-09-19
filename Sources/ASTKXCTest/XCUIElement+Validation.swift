import XCTest

public enum ElementRequirement: Sendable, CustomStringConvertible {
	case exists(Bool = true)
	case visible(Bool = true, scroll: Bool = false, maxSwipes: Int = 8)
	case tappable(Bool = true)
	case enabled(Bool = true)
	case nonEmptyText(Bool = true)

	public var description: String {
		switch self {
		case .exists(let expected):
			"exists(\(expected))"
		case .visible(let expected, let scroll, let maxSwipes):
			"visible(\(expected), scroll: \(scroll), maxSwipes: \(maxSwipes))"
		case .tappable(let expected):
			"tappable(\(expected))"
		case .enabled(let expected):
			"enabled(\(expected))"
		case .nonEmptyText(let expected):
			"nonEmptyText(\(expected))"
		}
	}
}

@MainActor
extension XCUIElement {
	@discardableResult
	public func requireAsync(
		identifier: String,
		timeout: TimeInterval = UITestTimeout.content,
		in app: XCUIApplication,
		_ checks: ElementRequirement...
	) async throws -> XCUIElement {
		try await requireAsync(
			identifier: identifier,
			checks: checks,
			timeout: timeout,
			in: app
		)
	}

	@discardableResult
	public func requireAsync(
		identifier: String,
		checks: [ElementRequirement],
		timeout: TimeInterval = UITestTimeout.content,
		in app: XCUIApplication
	) async throws -> XCUIElement {
		let deadline = Date().addingTimeInterval(timeout)

		for check in checks {
			let remaining = deadline.timeIntervalSinceNow
			guard remaining > 0 else {
				throw UITestElementError.requirementFailed(
					identifier: identifier,
					requirement: check,
					timeout: timeout
				)
			}

			switch check {
			case .exists(let expected):
				try await waitForExistsRequirement(
					identifier: identifier,
					expected: expected,
					timeout: remaining
				)
			case .visible(let expected, let scroll, let maxSwipes):
				if expected && scroll {
					try await scrollIntoViewIfNeededAsync(
						identifier: identifier,
						in: app,
						maxSwipes: maxSwipes
					)
				}
				try await waitForVisibleRequirement(
					identifier: identifier,
					expected: expected,
					timeout: remaining,
					in: app
				)
			case .tappable(let expected):
				try await waitForTappableRequirement(
					identifier: identifier,
					expected: expected,
					timeout: remaining
				)
			case .enabled(let expected):
				try await waitForEnabledRequirement(
					identifier: identifier,
					expected: expected,
					timeout: remaining
				)
			case .nonEmptyText(let expected):
				try await waitForNonEmptyTextRequirement(
					identifier: identifier,
					expected: expected,
					timeout: remaining
				)
			}
		}

		return self
	}

	@discardableResult
	public func scrollIntoViewIfNeededAsync(
		identifier: String,
		in app: XCUIApplication,
		maxSwipes: Int = 8
	) async throws -> XCUIElement {
		guard exists else {
			throw UITestElementError.notFound(identifier: identifier, timeout: 0)
		}

		if isVisible(in: app) {
			return self
		}

		let scrollContainer = findScrollContainer(in: app)
		for _ in 0 ..< maxSwipes {
			if isVisible(in: app) {
				return self
			}

			if frame.midY > app.windows.firstMatch.frame.midY {
				scrollContainer.swipeUp()
			} else {
				scrollContainer.swipeDown()
			}

			try await Task.sleep(nanoseconds: 100_000_000)
		}

		guard isVisible(in: app) else {
			throw UITestElementError.scrollFailed(identifier: identifier, maxSwipes: maxSwipes)
		}

		return self
	}

	func isVisible(in app: XCUIApplication) -> Bool {
		guard exists else { return false }

		let elementFrame = frame
		guard elementFrame.width > 0, elementFrame.height > 0 else { return false }

		let windowFrame = app.windows.firstMatch.frame
		guard windowFrame.width > 0, windowFrame.height > 0 else { return false }

		return elementFrame.intersects(windowFrame)
	}

	func hasNonEmptyText() -> Bool {
		let valueText = value as? String
		let candidates = [label, valueText, title]
		return candidates.contains { text in
			guard let text else { return false }
			return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
		}
	}

	private func waitForExistsRequirement(
		identifier: String,
		expected: Bool,
		timeout: TimeInterval
	) async throws {
		let satisfied = await waitUntil(timeout: timeout) {
			self.exists == expected
		}
		guard satisfied else {
			throw UITestElementError.requirementFailed(
				identifier: identifier,
				requirement: .exists(expected),
				timeout: timeout
			)
		}
	}

	private func waitForVisibleRequirement(
		identifier: String,
		expected: Bool,
		timeout: TimeInterval,
		in app: XCUIApplication
	) async throws {
		let satisfied = await waitUntil(timeout: timeout) {
			self.isVisible(in: app) == expected
		}
		guard satisfied else {
			throw UITestElementError.requirementFailed(
				identifier: identifier,
				requirement: .visible(expected),
				timeout: timeout
			)
		}
	}

	private func waitForTappableRequirement(
		identifier: String,
		expected: Bool,
		timeout: TimeInterval
	) async throws {
		let satisfied = await waitUntil(timeout: timeout) {
			guard self.exists else { return !expected }
			return self.isHittable == expected
		}
		guard satisfied else {
			throw UITestElementError.requirementFailed(
				identifier: identifier,
				requirement: .tappable(expected),
				timeout: timeout
			)
		}
	}

	private func waitForEnabledRequirement(
		identifier: String,
		expected: Bool,
		timeout: TimeInterval
	) async throws {
		let satisfied = await waitUntil(timeout: timeout) {
			guard self.exists else { return !expected }
			return self.isEnabled == expected
		}
		guard satisfied else {
			throw UITestElementError.requirementFailed(
				identifier: identifier,
				requirement: .enabled(expected),
				timeout: timeout
			)
		}
	}

	private func waitForNonEmptyTextRequirement(
		identifier: String,
		expected: Bool,
		timeout: TimeInterval
	) async throws {
		let satisfied = await waitUntil(timeout: timeout) {
			guard self.exists else { return !expected }
			return self.hasNonEmptyText() == expected
		}
		guard satisfied else {
			throw UITestElementError.requirementFailed(
				identifier: identifier,
				requirement: .nonEmptyText(expected),
				timeout: timeout
			)
		}
	}

	private func waitUntil(
		timeout: TimeInterval,
		pollInterval: TimeInterval = 0.1,
		condition: @escaping @MainActor () -> Bool
	) async -> Bool {
		let deadline = Date().addingTimeInterval(timeout)
		while Date() < deadline {
			if condition() {
				return true
			}
			try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
		}
		return condition()
	}

	private func findScrollContainer(in app: XCUIApplication) -> XCUIElement {
		let scrollTypes: [XCUIElement.ElementType] = [.scrollView, .collectionView, .table]
		for scrollType in scrollTypes {
			let query = app.descendants(matching: scrollType)
			if query.count > 0 {
				return query.firstMatch
			}
		}
		return app
	}
}
