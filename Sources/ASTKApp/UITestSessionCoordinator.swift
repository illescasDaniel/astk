import ASTK
import Foundation

@MainActor
public final class UITestSessionCoordinator<Configuration: Decodable> {
	public let settings: UITestSessionSettings
	public weak var scenarioHost: (any UITestScenarioApplying<Configuration>)?
	public weak var navigationResetter: (any UITestNavigationResetting)?

	public init(settings: UITestSessionSettings) {
		self.settings = settings
	}

	public func handleOpenURL(_ url: URL) {
		guard let configuration = UITestApplyHandler.configuration(
			from: url,
			settings: settings,
			as: Configuration.self
		) else {
			return
		}
		guard let scenarioHost else { return }
		navigationResetter?.resetNavigation()
		scenarioHost.apply(configuration)
	}
}
