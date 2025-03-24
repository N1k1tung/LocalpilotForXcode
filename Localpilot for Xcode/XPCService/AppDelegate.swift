import AppKit
import Foundation
import SwiftUI
import UserNotifications

let bundleIdentifierBase = Bundle.main
    .object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    @MainActor
    let service = Service.shared
    var statusBarItem: NSStatusItem!
    var xpcController: XPCController?
    
    func applicationDidFinishLaunching(_: Notification) {
        if ProcessInfo.processInfo.environment["IS_UNIT_TEST"] == "YES" { return }
        _ = XcodeInspector.shared
        service.start()
        AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true,
        ] as CFDictionary)
        setupQuitOnUserTerminated()
        xpcController = .init()
        dprint("XPC Service started.")
        NSApp.setActivationPolicy(.accessory)
        buildStatusBarMenu()
    }

    @objc func quit() {
        Task { @MainActor in
            await service.prepareForExit()
            await xpcController?.quit()
            NSApp.terminate(self)
        }
    }

    @objc func openHostApp() {
        let task = Process()
        if let appPath = locateHostBundleURL(url: Bundle.main.bundleURL)?.absoluteString {
            task.launchPath = "/usr/bin/open"
            task.arguments = [appPath]
            task.launch()
            task.waitUntilExit()
        }
    }

    func setupQuitOnUserTerminated() {
        Task {
            // Whenever Xcode or the host application quits, check if any of the two is running.
            // If none, quit the XPC service.

            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didTerminateApplicationNotification)
            for await notification in sequence {
                try Task.checkCancellation()
//                guard UserDefaults.shared.value(for: \.quitXPCServiceOnXcodeAndAppQuit)
//                else { continue }
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                    app.isUserOfService
                else { continue }
                if NSWorkspace.shared.runningApplications.contains(where: \.isUserOfService) {
                    continue
                }
                quit()
            }
        }
    }

    func requestAccessoryAPIPermission() {
        AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true,
        ] as NSDictionary)
    }

}

extension NSRunningApplication {
    var isUserOfService: Bool {
        [
            "com.apple.dt.Xcode",
            bundleIdentifierBase,
        ].contains(bundleIdentifier)
    }
}

func locateHostBundleURL(url: URL) -> URL? {
    var nextURL = url
    while nextURL.path != "/" {
        nextURL = nextURL.deletingLastPathComponent()
        if nextURL.lastPathComponent.hasSuffix(".app") {
            return nextURL
        }
    }
    let devAppURL = url
        .deletingLastPathComponent()
        .appendingPathComponent("Localpilot for Xcode Dev.app")
    return devAppURL
}

