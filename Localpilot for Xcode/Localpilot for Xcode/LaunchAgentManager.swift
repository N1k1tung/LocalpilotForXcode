import Foundation
import ServiceManagement

public struct LaunchAgentManager {
    let lastLaunchAgentVersionKey = "LastLaunchAgentVersion"
    let serviceIdentifier: String
    let executablePath: String
    let bundleIdentifier: String

    public init() {
        self.init(
            serviceIdentifier: Bundle.main
                .object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String +
                ".CommunicationBridge",
            executablePath: Bundle.main.bundleURL
                .appendingPathComponent("Contents")
                .appendingPathComponent("Applications")
                .appendingPathComponent("CommunicationBridge")
                .path,
            bundleIdentifier: Bundle.main
                .object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String
        )
    }

    private init(serviceIdentifier: String, executablePath: String, bundleIdentifier: String) {
        self.serviceIdentifier = serviceIdentifier
        self.executablePath = executablePath
        self.bundleIdentifier = bundleIdentifier
    }

    public func setupLaunchAgentForTheFirstTimeIfNeeded() async throws {
        try await setupLaunchAgent()
    }

    public func setupLaunchAgent() async throws {
        dprint("Registering bridge launch agent")
        let bridgeLaunchAgent = SMAppService.agent(plistName: "bridgeLaunchAgent.plist")
        try bridgeLaunchAgent.register()

        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        UserDefaults.standard.set(buildNumber, forKey: lastLaunchAgentVersionKey)
    }

    public func removeLaunchAgent() async throws {
        dprint("Unregistering bridge launch agent")
        let bridgeLaunchAgent = SMAppService.agent(plistName: "bridgeLaunchAgent.plist")
        try await bridgeLaunchAgent.unregister()
    }

}
