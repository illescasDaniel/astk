import Foundation

public enum LaunchEnvironmentCodec {
	public static func encode<T: Encodable>(_ value: T) -> String {
		do {
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.sortedKeys]
			let data = try encoder.encode(value)
			guard let string = String(data: data, encoding: .utf8) else {
				preconditionFailure("Launch environment JSON was not UTF-8")
			}
			return string
		} catch {
			preconditionFailure("Failed to encode launch environment: \(error)")
		}
	}

	public static func decode<T: Decodable>(_ value: String, as type: T.Type = T.self) -> T {
		guard let data = value.data(using: .utf8) else {
			preconditionFailure("Launch environment value was not UTF-8")
		}
		do {
			return try JSONDecoder().decode(T.self, from: data)
		} catch {
			preconditionFailure("Failed to decode launch environment: \(error)")
		}
	}

	public static func decodeIfPresent<T: Decodable>(
		_ value: String,
		as type: T.Type = T.self
	) -> T? {
		guard let data = value.data(using: .utf8) else { return nil }
		return try? JSONDecoder().decode(T.self, from: data)
	}
}
