import Testing
@testable import ASTK

@Suite
struct UITestReadyMarkerTests {

	@Test
	func `Given Session Generation When Identifier Built Then Uses Stable Prefix`() {
		#expect(UITestReadyMarker.identifier(sessionGeneration: 1) == "uitest-ready-1")
		#expect(UITestReadyMarker.identifier(sessionGeneration: 42) == "uitest-ready-42")
	}
}
