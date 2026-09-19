import XCTest

@MainActor
extension XCUIElement {
	/// Asynchronous alternative to `waitForExistence` using `XCTWaiter`.
	public func waitForExistenceAsync(timeout: TimeInterval) async -> Bool {
		let predicate = NSPredicate(format: "exists == true")
		let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
		let result = await XCTWaiter().fulfillment(of: [expectation], timeout: timeout)
		return result == .completed
	}
}
