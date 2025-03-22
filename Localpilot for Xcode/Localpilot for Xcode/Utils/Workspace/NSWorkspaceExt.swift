//
import AppKit
import Foundation

public extension NSWorkspace {
    /// Opens the System Preferences/Settings app at the Extensions pane
    /// - Parameter extensionPointIdentifier: Optional identifier for specific extension type
    static func openExtensionsPreferences(extensionPointIdentifier: String? = nil) {
        if #available(macOS 13.0, *) {
            var urlString = "x-apple.systempreferences:com.apple.ExtensionsPreferences"
            if let extensionPointIdentifier = extensionPointIdentifier {
                urlString += "?extensionPointIdentifier=\(extensionPointIdentifier)"
            }
            NSWorkspace.shared.open(URL(string: urlString)!)
        } else {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            process.arguments = [
                "-b",
                "com.apple.systempreferences",
                "/System/Library/PreferencePanes/Extensions.prefPane"
            ]

            do {
                try process.run()
            } catch {
                // Handle error silently
                return
            }
        }
    }

    /// Opens the Xcode Extensions preferences directly
    static func openXcodeExtensionsPreferences() {
        openExtensionsPreferences(extensionPointIdentifier: "com.apple.dt.Xcode.extension.source-editor")
    }

    static func restartXcode() {
        // Find current Xcode path before quitting
        var xcodeURL: URL?

        // Get currently running Xcode application URL
        if let xcodeApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.dt.Xcode" }) {
            xcodeURL = xcodeApp.bundleURL
        }

        // Fallback to standard path if we couldn't get the running instance
        if xcodeURL == nil {
            let standardPath = "/Applications/Xcode.app"
            if FileManager.default.fileExists(atPath: standardPath) {
                xcodeURL = URL(fileURLWithPath: standardPath)
            }
        }

        // Restart if we found a valid path
        if let xcodeURL = xcodeURL {
            // Quit Xcode
            let script = NSAppleScript(source: "tell application \"Xcode\" to quit")
            script?.executeAndReturnError(nil)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                NSWorkspace.shared.openApplication(
                    at: xcodeURL,
                    configuration: NSWorkspace.OpenConfiguration()
                )
            }
        }
    }
}
