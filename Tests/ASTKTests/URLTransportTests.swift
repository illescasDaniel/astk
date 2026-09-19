import Foundation
import Testing
@testable import ASTK

private struct SampleConfig: Codable, Equatable {
	var label: String
	var enabled: Bool
}

@Suite
struct URLTransportTests {

	private let settings = UITestSessionSettings(deepLinkScheme: "myapp-uitest")

	@Test
	func `Given Config When URL Query Encoded Then Round Trips`() {
		let original = SampleConfig(label: "scenario-a", enabled: true)
		let encoded = original.encodeToURLQueryValue()
		let decoded = SampleConfig.decodeFromURLQueryValue(encoded)
		#expect(decoded == original)
	}

	@Test
	func `Given Config When Deep Link Built Then Apply Handler Decodes`() throws {
		let original = SampleConfig(label: "scenario-b", enabled: false)
		let url = original.makeApplyDeepLinkURL(settings: settings)
		let decoded = UITestApplyHandler.configuration(
			from: url,
			settings: settings,
			as: SampleConfig.self
		)
		#expect(decoded == original)
	}

	@Test
	func `Given Wrong Scheme When Apply Handler Runs Then Returns Nil`() throws {
		let url = try #require(URL(string: "other://apply?config=abc"))
		let decoded = UITestApplyHandler.configuration(
			from: url,
			settings: settings,
			as: SampleConfig.self
		)
		#expect(decoded == nil)
	}

	@Test
	func `Given Wrong Host When Apply Handler Runs Then Returns Nil`() throws {
		let url = try #require(URL(string: "myapp-uitest://other?config=abc"))
		let decoded = UITestApplyHandler.configuration(
			from: url,
			settings: settings,
			as: SampleConfig.self
		)
		#expect(decoded == nil)
	}
}
