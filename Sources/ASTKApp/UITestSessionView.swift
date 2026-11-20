import ASTK
import Observation
import SwiftUI

/// DEBUG shell that recreates root UI on each scenario apply and exposes the ready marker.
public struct UITestSessionView<Content: View, Configuration: Decodable, Host>: View
where Host: UITestScenarioApplying & Observable, Host.Configuration == Configuration {
	@ViewBuilder private let content: () -> Content
	@Bindable private var scenarioHost: Host
	private let navigationResetter: (any UITestNavigationResetting)?
	private let coordinator: UITestSessionCoordinator<Configuration>
	@Binding private var uiTestSessionGeneration: Int

	public init(
		@ViewBuilder content: @escaping () -> Content,
		scenarioHost: Host,
		navigationResetter: (any UITestNavigationResetting)?,
		coordinator: UITestSessionCoordinator<Configuration>,
		uiTestSessionGeneration: Binding<Int>
	) {
		self.content = content
		self._scenarioHost = Bindable(scenarioHost)
		self.navigationResetter = navigationResetter
		self.coordinator = coordinator
		self._uiTestSessionGeneration = uiTestSessionGeneration
	}

	public var body: some View {
		ZStack(alignment: .topLeading) {
			content()
				.id(uiTestSessionGeneration)
			if uiTestSessionGeneration > 0 {
				Color.clear
					.frame(width: 1, height: 1)
					.accessibilityElement()
					.accessibilityIdentifier(
						UITestReadyMarker.identifier(sessionGeneration: uiTestSessionGeneration)
					)
					.allowsHitTesting(false)
			}
		}
		.onAppear {
			wireSessionRuntime()
		}
		.onChange(of: scenarioHost.sessionGeneration) { _, generation in
			uiTestSessionGeneration = generation
		}
	}

	private func wireSessionRuntime() {
		coordinator.scenarioHost = scenarioHost
		coordinator.navigationResetter = navigationResetter
		uiTestSessionGeneration = scenarioHost.sessionGeneration
	}
}

extension View {
	/// Wraps production root content for shared-process UI testing.
	public func uiTestSession<Configuration: Decodable, Host: UITestScenarioApplying & Observable>(
		host: Host,
		navigationResetter: (any UITestNavigationResetting)?,
		coordinator: UITestSessionCoordinator<Configuration>,
		uiTestSessionGeneration: Binding<Int>
	) -> some View where Host.Configuration == Configuration {
		UITestSessionView(
			content: { self },
			scenarioHost: host,
			navigationResetter: navigationResetter,
			coordinator: coordinator,
			uiTestSessionGeneration: uiTestSessionGeneration
		)
	}
}

/// Keeps the SwiftUI view hierarchy independent of host associated types.
@MainActor
private final class ManagedSessionRuntime {
	let generation: () -> Int
	let wire: () -> Void
	let handleURL: (URL) -> Void

	init<Host: UITestScenarioApplying & Observable>(
		host: Host, navigationResetter: (any UITestNavigationResetting)?,
		settings: UITestSessionSettings, isURLHandlingEnabled: @escaping () -> Bool
	) {
		let coordinator = UITestSessionCoordinator<Host.Configuration>(settings: settings)
		generation = { host.sessionGeneration }
		wire = {
			coordinator.scenarioHost = host
			coordinator.navigationResetter = navigationResetter
		}
		handleURL = { url in
			guard isURLHandlingEnabled() else { return }
			coordinator.handleOpenURL(url)
		}
	}
}

private struct ManagedUITestSession: ViewModifier {
	@State private var generation = 0
	@State private var runtime: ManagedSessionRuntime

	init(runtime: ManagedSessionRuntime) {
		_runtime = State(initialValue: runtime)
	}

	func body(content: Content) -> some View {
		ZStack(alignment: .topLeading) {
			content.id(generation)
			if generation > 0 {
				Color.clear
					.frame(width: 1, height: 1)
					.accessibilityElement()
					.accessibilityIdentifier(UITestReadyMarker.identifier(sessionGeneration: generation))
					.allowsHitTesting(false)
			}
		}
		.onAppear {
			runtime.wire()
			generation = runtime.generation()
		}
		.onChange(of: runtime.generation()) { _, value in generation = value }
		.onOpenURL { runtime.handleURL($0) }
	}
}

extension View {
	/// Wraps a test root, owning session state and handling scenario URLs.
	/// The host, resetter, settings and URL predicate are captured for the view's
	/// lifetime. Give the view a new identity to replace them.
	public func uiTestSession<Host: UITestScenarioApplying & Observable>(
		host: Host,
		navigationResetter: (any UITestNavigationResetting)? = nil,
		settings: UITestSessionSettings,
		isURLHandlingEnabled: @escaping () -> Bool = { true }
	) -> AnyView {
		AnyView(modifier(ManagedUITestSession(runtime: ManagedSessionRuntime(
			host: host, navigationResetter: navigationResetter,
			settings: settings, isURLHandlingEnabled: isURLHandlingEnabled))))
	}
}
