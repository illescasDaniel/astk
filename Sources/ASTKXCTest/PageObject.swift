import XCTest

@MainActor
public protocol PageObject {
	var app: XCUIApplication { get }
	init(app: XCUIApplication)
}
