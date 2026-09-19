import Foundation
import Testing
@testable import ASTK

private struct SampleConfig: Codable, Equatable {
	var name: String
	var count: Int
}

@Suite
struct LaunchEnvironmentCodecTests {

	@Test
	func `Given Encodable Value When Encoded Then JSON Round Trips`() {
		let original = SampleConfig(name: "alpha", count: 3)
		let encoded = LaunchEnvironmentCodec.encode(original)
		let decoded = LaunchEnvironmentCodec.decode(encoded, as: SampleConfig.self)
		#expect(decoded == original)
	}

	@Test
	func `Given Invalid JSON When Decoded If Present Then Returns Nil`() {
		#expect(SampleConfig.decodeIfPresent(fromLaunchEnvironmentValue: "{") == nil)
	}
}
