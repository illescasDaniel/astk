import Foundation

public enum UITestApplyHandler {
	public static func configuration<T: Decodable>(
		from url: URL,
		settings: UITestSessionSettings,
		as type: T.Type = T.self
	) -> T? {
		guard url.scheme == settings.deepLinkScheme else { return nil }
		guard url.host == settings.applyHost else { return nil }
		guard
			let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
			let encoded = components.queryItems?
				.first(where: { $0.name == settings.configQueryKey })?
				.value
		else {
			return nil
		}
		return T.decodeFromURLQueryValue(encoded)
	}
}
