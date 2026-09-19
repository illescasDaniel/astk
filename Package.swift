// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "AsyncSharedTestingKit",
	platforms: [.iOS("18.0"), .macOS("14.0")],
	products: [
		.library(name: "ASTK", targets: ["ASTK"]),
		.library(name: "ASTKApp", targets: ["ASTKApp"]),
		.library(name: "ASTKXCTest", targets: ["ASTKXCTest"]),
	],
	targets: [
		.target(
			name: "ASTK",
			path: "Sources/ASTK"
		),
		.target(
			name: "ASTKApp",
			dependencies: ["ASTK"],
			path: "Sources/ASTKApp"
		),
		.target(
			name: "ASTKXCTest",
			dependencies: ["ASTK"],
			path: "Sources/ASTKXCTest",
			linkerSettings: [
				.linkedFramework("XCTest"),
			]
		),
		.testTarget(
			name: "ASTKTests",
			dependencies: ["ASTK"],
			path: "Tests/ASTKTests"
		),
	]
)
