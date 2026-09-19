import Testing
@testable import ASTK

@Suite
@MainActor
struct UITestSessionHostTests {

	@Test
	func `Given Host When Apply Called Then Generation Increments And Callback Runs`() {
		var applied: SampleConfig?
		let host = UITestSessionHost<SampleConfig> { applied = $0 }
		#expect(host.sessionGeneration == 0)

		host.apply(SampleConfig(id: 1))
		#expect(host.sessionGeneration == 1)
		#expect(applied == SampleConfig(id: 1))

		host.apply(SampleConfig(id: 2))
		#expect(host.sessionGeneration == 2)
		#expect(applied == SampleConfig(id: 2))
	}
}

private struct SampleConfig: Codable, Equatable {
	var id: Int
}
