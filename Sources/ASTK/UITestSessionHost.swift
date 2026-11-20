import Observation

/// Generic scenario host that stores the latest configuration and bumps `sessionGeneration`.
@MainActor
@Observable
public final class UITestSessionHost<Configuration: Codable> {
	public private(set) var sessionGeneration: Int
	public private(set) var configuration: Configuration?
	public var onApply: ((Configuration) -> Void)?

	public init(initialGeneration: Int = 0, onApply: ((Configuration) -> Void)? = nil) {
		self.sessionGeneration = initialGeneration
		self.onApply = onApply
	}

	public func apply(_ configuration: Configuration) {
		self.configuration = configuration
		onApply?(configuration)
		sessionGeneration += 1
	}
}

extension UITestSessionHost: UITestScenarioApplying {}
