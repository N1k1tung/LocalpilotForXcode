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

}
