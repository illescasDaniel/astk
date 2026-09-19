import ASTK
import XCTest

@MainActor
extension XCUIApplication {
	public func waitForUITestReady(
		sessionGeneration: Int,
		timeout: TimeInterval = UITestTimeout.screen
	) throws {
		let identifier = UITestReadyMarker.identifier(sessionGeneration: sessionGeneration)
		try waitForElement(matching: identifier, timeout: timeout)
	}

	public func waitForUITestReadyAsync(
		sessionGeneration: Int,
		timeout: TimeInterval = UITestTimeout.screen
	) async throws {
		let identifier = UITestReadyMarker.identifier(sessionGeneration: sessionGeneration)
		try await waitForElementAsync(matching: identifier, timeout: timeout)
	}

	public func element(matching identifier: String) -> XCUIElement {
		descendants(matching: .any).matching(identifier: identifier).firstMatch
	}

	public func elements(matchingIdentifierPrefix prefix: String) -> XCUIElementQuery {
		descendants(matching: .any)
			.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
	}

	@discardableResult
	public func waitForElement(
		matching identifier: String,
		timeout: TimeInterval = UITestTimeout.screen
	) throws -> XCUIElement {
		try element(matching: identifier)
			.requireExistence(identifier: identifier, timeout: timeout)
	}

	@discardableResult
	public func waitForElementAsync(
		matching identifier: String,
		timeout: TimeInterval = UITestTimeout.screen
	) async throws -> XCUIElement {
		try await element(matching: identifier)
			.requireExistenceAsync(identifier: identifier, timeout: timeout)
	}

	@discardableResult
	public func waitForElements(
		matchingIdentifierPrefix prefix: String,
		timeout: TimeInterval = UITestTimeout.content
	) throws -> XCUIElementQuery {
		let query = elements(matchingIdentifierPrefix: prefix)
		_ = try query.firstMatch.requireExistence(
			identifier: "\(prefix)*",
			timeout: timeout
		)
		return query
	}

	@discardableResult
	public func waitForElementsAsync(
		matchingIdentifierPrefix prefix: String,
		timeout: TimeInterval = UITestTimeout.content
	) async throws -> XCUIElementQuery {
		let query = elements(matchingIdentifierPrefix: prefix)
		_ = try await query.firstMatch.requireExistenceAsync(
			identifier: "\(prefix)*",
			timeout: timeout
		)
		return query
	}

	public func requireNoElements(
		matchingIdentifierPrefix prefix: String,
		timeout: TimeInterval = UITestTimeout.absence
	) throws {
		try elements(matchingIdentifierPrefix: prefix).firstMatch
			.requireAbsence(identifier: "\(prefix)*", timeout: timeout)
	}

	public func requireNoElementsAsync(
		matchingIdentifierPrefix prefix: String,
		timeout: TimeInterval = UITestTimeout.absence
	) async throws {
		try await elements(matchingIdentifierPrefix: prefix).firstMatch
			.requireAsync(
				identifier: "\(prefix)*",
				timeout: timeout,
				in: self,
				.exists(false)
			)
	}
}
