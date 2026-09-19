import XCTest

@MainActor
public protocol NestedPageObject {
	var root: XCUIElement { get }
	var app: XCUIApplication { get }
}

extension NestedPageObject {
	public func childElement(
		matching identifier: String,
		timeout: TimeInterval = UITestTimeout.content
	) async throws -> XCUIElement {
		let element = root.descendants(matching: .any)
			.matching(identifier: identifier)
			.firstMatch
		return try await element.requireExistenceAsync(
			identifier: identifier,
			timeout: timeout
		)
	}
}
