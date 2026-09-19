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
