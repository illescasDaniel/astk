import Foundation

/// Shared-process UI test environment and deep-link transport settings.
///
/// Only `deepLinkScheme` is typically app-specific; register it in Info.plist.
public struct UITestSessionSettings: Sendable, Equatable {
	public var deepLinkScheme: String
	public var testingKey: String
	public var configKey: String
	public var applyHost: String
	public var configQueryKey: String

	public init(
		deepLinkScheme: String,
		testingKey: String = "UITESTING",
		configKey: String = "UITEST_CONFIG",
		applyHost: String = "apply",
		configQueryKey: String = "config"
	) {
		self.deepLinkScheme = deepLinkScheme
		self.testingKey = testingKey
		self.configKey = configKey
		self.applyHost = applyHost
		self.configQueryKey = configQueryKey
	}
}
