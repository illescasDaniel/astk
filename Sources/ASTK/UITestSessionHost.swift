import Observation

/// Generic scenario host that stores the latest configuration and bumps `sessionGeneration`.
@MainActor
@Observable
public final class UITestSessionHost<Configuration: Codable> {
	public private(set) var sessionGeneration = 0
	public var onApply: ((Configuration) -> Void)?

	public init(onApply: ((Configuration) -> Void)? = nil) {
		self.onApply = onApply
	}

	public func apply(_ configuration: Configuration) {
		onApply?(configuration)
		sessionGeneration += 1
	}
}

extension UITestSessionHost: UITestScenarioApplying {}
