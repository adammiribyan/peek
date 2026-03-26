import Foundation

extension Bundle {
	/// Custom replacement for SPM's auto-generated ``Bundle.module``.
	///
	/// SPM's default accessor only checks `Bundle.main.bundleURL` (the `.app` root),
	/// but macOS codesigning requires resource bundles in `Contents/Resources/`.
	/// This accessor searches both locations.
	static let module: Bundle = {
		let bundleName = "KeyboardShortcuts_KeyboardShortcuts"

		let candidates = [
			// .app bundle: Contents/Resources/ (correct for codesigned macOS apps)
			Bundle.main.resourceURL,
			// .app root or CLI tool directory (SPM default)
			Bundle.main.bundleURL,
			// Next to the executable (swift run / swift build)
			Bundle.main.executableURL?.deletingLastPathComponent(),
		]

		for candidate in candidates {
			let bundlePath = candidate?.appendingPathComponent(bundleName + ".bundle")
			if let bundle = bundlePath.flatMap(Bundle.init(url:)) {
				return bundle
			}
		}

		// Graceful fallback: return main bundle so NSLocalizedString shows keys
		// instead of crashing with fatalError
		return Bundle.main
	}()
}
