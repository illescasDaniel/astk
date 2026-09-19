import ASTK
import XCTest

@MainActor
public final class SharedProcessLauncher<Configuration: Encodable, RootPage: PageObject> {
	public let settings: UITestSessionSettings
	public private(set) var app: XCUIApplication?
	public private(set) var sessionGeneration = 0
	private let makeRootPage: (XCUIApplication) -> RootPage
	private let prepareForApply: (XCUIApplication) -> Void

	public init(
		settings: UITestSessionSettings,
		makeRootPage: @escaping (XCUIApplication) -> RootPage,
		prepareForApply: @escaping (XCUIApplication) -> Void = { _ in }
	) {
		self.settings = settings
		self.makeRootPage = makeRootPage
		self.prepareForApply = prepareForApply
	}

	/// Launches the app once under shared-process UI testing (`UITESTING=1`).
	public func ensureLaunched() throws -> RootPage {
		if let app, app.state == .runningForeground {
			return makeRootPage(app)
		}
		let application = XCUIApplication()
		application.terminate()
		application.launchEnvironment = [
			settings.testingKey: "1",
		]
		application.launch()
		app = application
		sessionGeneration = 1
		try application.waitForUITestReady(sessionGeneration: sessionGeneration)
		return makeRootPage(application)
	}

	/// Applies a scenario without relaunching: prepare, open DEBUG deep link, wait for ready marker.
	@discardableResult
	public func apply(configuration: Configuration) async throws -> RootPage {
		_ = try ensureLaunched()
		guard let app else {
			preconditionFailure("Shared-process UI test app was not launched")
		}
		sessionGeneration += 1
		let generation = sessionGeneration
		prepareForApply(app)
		let url = configuration.makeApplyDeepLinkURL(settings: settings)
		app.activate()
		XCUIDevice.shared.system.open(url)
		try await app.waitForUITestReadyAsync(sessionGeneration: generation)
		return makeRootPage(app)
	}
}
