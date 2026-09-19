import Foundation

/// Accessibility identifier for the invisible session-ready handshake marker.
public enum UITestReadyMarker {
	public static func identifier(sessionGeneration: Int) -> String {
		"uitest-ready-\(sessionGeneration)"
	}
}
