//

import Foundation

final class GeneralSettingsViewModel: ObservableObject {
    @UserDefaultsNonNilKey(key: "extensionPermissionShown", defaultValue: false)
    var extensionPermissionShown: Bool
    @UserDefaultsNonNilKey(key: "quitXPCServiceOnXcodeAndAppQuit", defaultValue: false)
    var quitXPCServiceOnXcodeAndAppQuit: Bool

    @Published var shouldPresentExtensionPermissionAlert = false
    @Published var shouldShowRestartXcodeAlert = false

    private(set) var xpcServiceVersion: String?
    private(set) var isAccessibilityPermissionGranted: ObservedAXStatus = .unknown
    private(set) var isExtensionPermissionGranted: ExtensionPermissionStatus = .unknown
    private(set) var isReloading = false
    private var reloadTask: Task<Void, Error>?

    func didAppear() {
        Task {
            await setupLaunchAgentIfNeeded()
            for await _ in DistributedNotificationCenter.default().notifications(named: .serviceStatusDidChange) {
                await reloadStatus()
            }
        }
    }

    func setupLaunchAgentIfNeeded() async {
#if DEBUG
                // do not auto install on debug build
                await reloadStatus()
#else
                Task {
                    do {
                        try await LaunchAgentManager()
                            .setupLaunchAgentForTheFirstTimeIfNeeded()
                    } catch {
                        print("Failed to setup launch agent. \(error.localizedDescription)")
//                        toast(error.localizedDescription, .error)
                    }
                    await reloadStatus()
                }
#endif
    }

    func openExtensionManager() async {
        do {
            let service = try getService()
            _ = try await service
                .send(requestBody: ExtensionServiceRequests.OpenExtensionManager())
        } catch {
            print("Failed to open extension manager. \(error.localizedDescription)")
            //                    toast(error.localizedDescription, .error)
            failedReloading()
        }
    }

    func reloadStatus() async {
        guard !isReloading else { return }
        isReloading = true
        reloadTask = Task {
            let service = try getService()
            do {
                let isCommunicationReady = try await service.launchIfNeeded()
                if isCommunicationReady {
                    let xpcServiceVersion = try await service.getXPCServiceVersion().version
                    let isAccessibilityPermissionGranted = try await service
                        .getXPCServiceAccessibilityPermission()
                    let isExtensionPermissionGranted = try await service.getXPCServiceExtensionPermission()
                    finishReloading(
                        version: xpcServiceVersion,
                        axStatus: isAccessibilityPermissionGranted,
                        extensionStatus: isExtensionPermissionGranted
                    )
                } else {
//                    toast("Launching service app.", .info)
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    await retryReloading()
                }
            } catch let error as XPCCommunicationBridgeError {
                print("Failed to reach communication bridge. \(error.localizedDescription)")
//                toast(
//                    "Failed to reach communication bridge. \(error.localizedDescription)",
//                    .error
//                )
                failedReloading()
            } catch {
                print("Failed to reload status. \(error.localizedDescription)")
//                toast(error.localizedDescription, .error)
                failedReloading()
            }
        }
    }

    func finishReloading(version: String?, axStatus: ObservedAXStatus, extensionStatus: ExtensionPermissionStatus) {
        xpcServiceVersion = version
        isAccessibilityPermissionGranted = axStatus
        isExtensionPermissionGranted = extensionStatus
        isReloading = false
    }

    func failedReloading() {
        isReloading = false
    }
    func retryReloading() async {
        isReloading = false
        await reloadStatus()
    }

    private lazy var service = XPCExtensionService()
    private func getService() throws -> XPCExtensionService {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            struct RunningInPreview: Error {}
            throw RunningInPreview()
        }
        return service
    }

}
