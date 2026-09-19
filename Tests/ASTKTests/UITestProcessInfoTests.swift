import Testing
@testable import ASTK

private struct SampleConfig: Codable, Equatable {
	var id: Int
}

@Suite
struct UITestProcessInfoTests {

	private let settings = UITestSessionSettings(deepLinkScheme: "myapp-uitest")

	@Test
	func `Given UITESTING When Checked Then Shared Process Mode Is True`() {
		let info = UITestProcessInfo(environment: ["UITESTING": "1"])
		#expect(info.isSharedProcessUITesting(settings: settings))
		#expect(info.isRunningUITests(settings: settings))
	}

	@Test
	func `Given UITEST_CONFIG When Checked Then Initial Configuration Decodes`() {
		let config = SampleConfig(id: 7)
		let info = UITestProcessInfo(environment: [
			"UITEST_CONFIG": config.encodeToLaunchEnvironmentValue(),
		])
		#expect(!info.isSharedProcessUITesting(settings: settings))
		#expect(info.isRunningUITests(settings: settings))
		#expect(info.initialConfiguration(settings: settings, as: SampleConfig.self) == config)
	}

	@Test
	func `Given Empty Environment When Checked Then Not Running UI Tests`() {
		let info = UITestProcessInfo(environment: [:])
		#expect(!info.isSharedProcessUITesting(settings: settings))
		#expect(!info.isRunningUITests(settings: settings))
	}
}
