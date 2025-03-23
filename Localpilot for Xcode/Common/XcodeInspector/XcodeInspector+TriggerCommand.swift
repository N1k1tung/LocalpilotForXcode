import AppKit
import Foundation

public extension XcodeAppInstanceInspector {
    func triggerCopilotCommand(name: String, activateXcode: Bool = true) async throws {
        let bundleName = Bundle.main.object(forInfoDictionaryKey: "EXTENSION_BUNDLE_NAME") as! String
        let status = await getExtensionStatus(bundleName: bundleName)
        guard status == .granted else {
            let reason: String
            switch status {
            case .notGranted:
                reason = "No bundle found for \(bundleName)."
            case .disabled:
                reason = "\(bundleName) is found but disabled."
            default:
                reason = ""
            }
            throw CantRunCommand(path: "Editor/\(bundleName)/\(name)", reason: reason)
        }
        
        try await triggerMenuItem(path: ["Editor", bundleName, name], activateApp: activateXcode)
    }
    
    private func getExtensionStatus(bundleName: String) async -> ExtensionPermissionStatus {
        let app = AXUIElementCreateApplication(runningApplication.processIdentifier)
        
        guard let menuBar = app.menuBar,
              let editorMenu = menuBar.child(title: "Editor") else {
            return .notGranted
        }
        
        if let bundleMenuItem = editorMenu.child(title: bundleName, role: "AXMenuItem") {
            var enabled: CFTypeRef?
            let error = AXUIElementCopyAttributeValue(bundleMenuItem, kAXEnabledAttribute as CFString, &enabled)
            if error == .success, let isEnabled = enabled as? Bool {
                return isEnabled ? .granted : .disabled
            }
            return .disabled
        }
        
        return .notGranted
    }
}

public extension AppInstanceInspector {
    struct CantRunCommand: Error, LocalizedError {
        let path: String
        let reason: String
        public var errorDescription: String {
            "Can't run command \(path): \(reason)"
        }
    }

    @MainActor
    func triggerMenuItem(path: [String], activateApp: Bool) async throws {
        let sourcePath = path.joined(separator: "/")
        func cantRunCommand(_ reason: String) -> CantRunCommand {
            return CantRunCommand(path: sourcePath, reason: reason)
        }

        guard path.count >= 2 else { throw cantRunCommand("Path too short.") }

        if activateApp {
            if !runningApplication.activate() {
                print("""
                Trigger menu item \(sourcePath): \
                Xcode not activated.
                """)
            }
        } else {
            if !runningApplication.isActive {
                print("""
                Trigger menu item \(sourcePath): \
                Xcode not activated.
                """)
            }
        }

        await Task.yield()

        let app = AXUIElementCreateApplication(runningApplication.processIdentifier)

        guard let menuBar = app.menuBar else {
            print("""
                Trigger menu item \(sourcePath) failed: \
                Menu not found.
                """)
            throw cantRunCommand("Menu not found.")
        }
        var path = path
        var currentMenu = menuBar
        while !path.isEmpty {
            let item = path.removeFirst()

            if path.isEmpty, let button = currentMenu.child(title: item, role: "AXMenuItem") {
                let error = AXUIElementPerformAction(button, kAXPressAction as CFString)
                if error != AXError.success {
                    print("""
                        Trigger menu item \(sourcePath) failed: \
                        \(error.localizedDescription)
                        """)
                    throw cantRunCommand(error.localizedDescription)
                } else {
                    dprint("""
                        Trigger menu item \(sourcePath) succeeded.
                        """)
                    return
                }
            } else if let menu = currentMenu.child(title: item) {
                dprint("""
                    Trigger menu item \(sourcePath): Move to \(item).
                    """)
                currentMenu = menu
            } else {
                print("""
                    Trigger menu item \(sourcePath) failed: \
                    \(item) is not found.
                    """)
                throw cantRunCommand("\(item) is not found.")
            }
        }
    }
}
