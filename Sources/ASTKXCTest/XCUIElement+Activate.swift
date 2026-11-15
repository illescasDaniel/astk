import XCTest

extension XCUIElement {
	/// Activates the element the way a user would on the current platform.
	///
	/// On macOS `tap()` on a SwiftUI control does not deliver a mouse click to the app
	/// (no mouse-down/up reaches it, so the control's action never fires), while
	/// `click()` does. On other platforms this is `tap()`.
	public func tapOrClick() {
		#if os(macOS)
		click()
		#else
		tap()
		#endif
	}
}
