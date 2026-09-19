import Foundation

extension Encodable {
	public func encodeToLaunchEnvironmentValue() -> String {
		LaunchEnvironmentCodec.encode(self)
	}

	public func encodeToURLQueryValue() -> String {
		let json = encodeToLaunchEnvironmentValue()
		return Data(json.utf8)
			.base64EncodedString()
			.replacingOccurrences(of: "+", with: "-")
			.replacingOccurrences(of: "/", with: "_")
			.replacingOccurrences(of: "=", with: "")
	}

	public func makeApplyDeepLinkURL(settings: UITestSessionSettings) -> URL {
		var components = URLComponents()
		components.scheme = settings.deepLinkScheme
		components.host = settings.applyHost
		components.queryItems = [
			URLQueryItem(name: settings.configQueryKey, value: encodeToURLQueryValue()),
		]
		guard let url = components.url else {
			preconditionFailure("Failed to build UI test apply deep link")
		}
		return url
	}
}

extension Decodable {
	public static func decodeIfPresent(fromLaunchEnvironmentValue value: String) -> Self? {
		LaunchEnvironmentCodec.decodeIfPresent(value, as: Self.self)
	}

	public static func decode(fromLaunchEnvironmentValue value: String) -> Self {
		LaunchEnvironmentCodec.decode(value, as: Self.self)
	}

	public static func decodeFromURLQueryValue(_ value: String) -> Self? {
		var base64 = value
			.replacingOccurrences(of: "-", with: "+")
			.replacingOccurrences(of: "_", with: "/")
		let padding = (4 - base64.count % 4) % 4
		base64.append(String(repeating: "=", count: padding))
		guard
			let data = Data(base64Encoded: base64),
			let json = String(data: data, encoding: .utf8)
		else {
			return nil
		}
		return decodeIfPresent(fromLaunchEnvironmentValue: json)
	}
}
