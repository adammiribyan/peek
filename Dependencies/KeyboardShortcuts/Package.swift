// swift-tools-version:6.1
import PackageDescription

let package = Package(
	name: "KeyboardShortcuts",
	platforms: [
		.macOS(.v10_15)
	],
	products: [
		.library(
			name: "KeyboardShortcuts",
			targets: [
				"KeyboardShortcuts"
			]
		)
	],
	targets: [
		.target(
			name: "KeyboardShortcuts",
			exclude: ["Localization"],
			swiftSettings: [
				.swiftLanguageMode(.v5)
			]
		)
	]
)
