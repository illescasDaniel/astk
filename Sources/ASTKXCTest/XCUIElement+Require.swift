import XCTest

public enum UITestElementError: Error, LocalizedError {
	case notFound(identifier: String, timeout: TimeInterval)
	case unexpectedlyPresent(identifier: String, timeout: TimeInterval)
	case requirementFailed(identifier: String, requirement: ElementRequirement, timeout: TimeInterval)
	case scrollFailed(identifier: String, maxSwipes: Int)

	public var errorDescription: String? {
		switch self {
		case .notFound(let identifier, let timeout):
			"Element '\(identifier)' not found within \(timeout)s"
		case .unexpectedlyPresent(let identifier, let timeout):
			"Element '\(identifier)' still present after \(timeout)s"
		case .requirementFailed(let identifier, let requirement, let timeout):
			"Element '\(identifier)' failed requirement \(requirement) within \(timeout)s"
		case .scrollFailed(let identifier, let maxSwipes):
			"Element '\(identifier)' could not be scrolled into view within \(maxSwipes) swipes"
		}
	}
}

public enum UITestTimeout {
	public static let screen: TimeInterval = 10
	public static let content: TimeInterval = 15
	public static let emptyState: TimeInterval = 20
	public static let absence: TimeInterval = 2
}

@MainActor
extension XCUIElement {
	@discardableResult
	public func requireExistence(
		identifier: String,
		timeout: TimeInterval
	) throws -> XCUIElement {
		guard waitForExistence(timeout: timeout) else {
			throw UITestElementError.notFound(identifier: identifier, timeout: timeout)
		}
		return self
	}

	@discardableResult
	public func requireExistenceAsync(
		identifier: String,
		timeout: TimeInterval
	) async throws -> XCUIElement {
		guard await waitForExistenceAsync(timeout: timeout) else {
			throw UITestElementError.notFound(identifier: identifier, timeout: timeout)
		}
		return self
	}

	public func requireAbsence(
		identifier: String,
		timeout: TimeInterval = UITestTimeout.absence
	) throws {
		if waitForExistence(timeout: timeout) {
			throw UITestElementError.unexpectedlyPresent(identifier: identifier, timeout: timeout)
		}
	}

	public func requireAbsenceAsync(
		identifier: String,
		timeout: TimeInterval = UITestTimeout.absence
	) async throws {
		if await waitForExistenceAsync(timeout: timeout) {
			throw UITestElementError.unexpectedlyPresent(identifier: identifier, timeout: timeout)
		}
	}
}
