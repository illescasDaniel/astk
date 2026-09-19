@MainActor
public protocol UITestScenarioApplying<Configuration>: AnyObject {
	associatedtype Configuration: Decodable
	var sessionGeneration: Int { get }
	func apply(_ configuration: Configuration)
}
