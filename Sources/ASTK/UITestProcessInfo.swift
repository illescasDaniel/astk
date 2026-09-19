import Foundation

/// Process environment helpers for shared-process and legacy launch-environment UI tests.
public struct UITestProcessInfo: Sendable {
	public var environment: [String: String]

	public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
		self.environment = environment
	}

	public func isSharedProcessUITesting(settings: UITestSessionSettings) -> Bool {
		environment[settings.testingKey] == "1"
	}

	public func configurationJSON(settings: UITestSessionSettings) -> String? {
		environment[settings.configKey]
	}

	public func isRunningUITests(settings: UITestSessionSettings) -> Bool {
		isSharedProcessUITesting(settings: settings) || configurationJSON(settings: settings) != nil
	}

	public func initialConfiguration<T: Decodable>(
		settings: UITestSessionSettings,
		as type: T.Type = T.self
	) -> T? {
		guard let raw = configurationJSON(settings: settings) else { return nil }
		return T.decodeIfPresent(fromLaunchEnvironmentValue: raw)
	}
}
