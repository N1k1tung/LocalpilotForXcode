import AppKit
import Foundation

@objc public enum ExtensionPermissionStatus: Int {
    case unknown = -1, notGranted = 0, disabled = 1, granted = 2
}

@objc public enum ObservedAXStatus: Int {
    case unknown = -1, granted = 1, notGranted = 0
}

public struct CLSStatus: Equatable {
    public enum Status { case unknown, normal, inProgress, error, warning, inactive }
    public let status: Status
    public let message: String
    
    public var isInactiveStatus: Bool { status == .inactive && !message.isEmpty }
    public var isErrorStatus: Bool { (status == .warning || status == .error) && !message.isEmpty }
}

private struct CLSStatusInfo {
    let icon: StatusResponse.Icon?
    let message: String
}

private struct AccessibilityStatusInfo {
    let icon: StatusResponse.Icon?
    let message: String?
    let url: String?
}

public extension Notification.Name {
    static let authStatusDidChange = Notification.Name("com.n1k1tung.LocalpilotForXcode.authStatusDidChange")
    static let serviceStatusDidChange = Notification.Name("com.n1k1tung.LocalpilotForXcode.serviceStatusDidChange")
}

public struct StatusResponse {
    public struct Icon {
        /// Name of the icon resource
        public let name: String

        public init(name: String) {
            self.name = name
        }

        public var nsImage: NSImage? {
            return NSImage(named: name)
        }
    }

    /// The icon to display in the menu bar
    public let icon: Icon
    /// Indicates if an operation is in progress
    public let inProgress: Bool
    /// Message from the CLS (Copilot Language Server) status
    public let clsMessage: String
    /// Additional message (for accessibility or extension status)
    public let message: String?
    /// Extension status
    public let extensionStatus: ExtensionPermissionStatus
    /// URL for system preferences or other actions
    public let url: String?
}

public final actor Status {
    public static let shared = Status()

    private var extensionStatus: ExtensionPermissionStatus = .unknown
    private var axStatus: ObservedAXStatus = .unknown
    private var clsStatus = CLSStatus(status: .unknown, message: "")

    private let okIcon = StatusResponse.Icon(name: "MenuBarIcon")
    private let errorIcon = StatusResponse.Icon(name: "MenuBarWarningIcon")
    private let inactiveIcon = StatusResponse.Icon(name: "MenuBarInactiveIcon")

    private init() {}

    public func updateExtensionStatus(_ status: ExtensionPermissionStatus) {
        guard status != extensionStatus else { return }
        extensionStatus = status
        broadcast()
    }

    public func updateAXStatus(_ status: ObservedAXStatus) {
        guard status != axStatus else { return }
        axStatus = status
        broadcast()
    }

    public func updateCLSStatus(_ status: CLSStatus.Status, message: String) {
        let newStatus = CLSStatus(status: status, message: message)
        guard newStatus != clsStatus else { return }
        clsStatus = newStatus
        broadcast()
    }

    public func getExtensionStatus() -> ExtensionPermissionStatus {
        extensionStatus
    }

    public func getAXStatus() -> ObservedAXStatus {
        if isXcodeRunning() {
            return axStatus
        } else if AXIsProcessTrusted() {
            return .granted
        } else {
            return axStatus
        }
    }

    private func isXcodeRunning() -> Bool {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.dt.Xcode"
        ).isEmpty
    }

    public func getCLSStatus() -> CLSStatus {
        clsStatus
    }

    public func getStatus() -> StatusResponse {
        let clsStatusInfo: CLSStatusInfo = getCLSStatusInfo()
        let extensionStatusIcon = (
            extensionStatus == ExtensionPermissionStatus.disabled || extensionStatus == ExtensionPermissionStatus.notGranted
        ) ? errorIcon : nil
        let accessibilityStatusInfo: AccessibilityStatusInfo = getAccessibilityStatusInfo()
        return .init(
            icon: clsStatusInfo.icon ?? extensionStatusIcon ?? accessibilityStatusInfo.icon ?? okIcon,
            inProgress: clsStatus.status == .inProgress,
            clsMessage: clsStatus.message,
            message: accessibilityStatusInfo.message,
            extensionStatus: extensionStatus,
            url: accessibilityStatusInfo.url
        )
    }

    private func getCLSStatusInfo() -> CLSStatusInfo {
        if clsStatus.isInactiveStatus {
            return CLSStatusInfo(icon: inactiveIcon, message: clsStatus.message)
        }
        if clsStatus.isErrorStatus {
            return CLSStatusInfo(icon: errorIcon, message: clsStatus.message)
        }
        return CLSStatusInfo(icon: nil, message: "")
    }

    private func getAccessibilityStatusInfo() -> AccessibilityStatusInfo {
        switch getAXStatus() {
        case .granted:
            return AccessibilityStatusInfo(icon: nil, message: nil, url: nil)
        case .notGranted:
            return AccessibilityStatusInfo(
                icon: errorIcon,
                message: """
                Enable accessibility in system preferences
                """,
                url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
        case .unknown:
            return AccessibilityStatusInfo(
                icon: errorIcon,
                message: """
                Enable accessibility or restart Copilot
                """,
                url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )
        }
    }

    private func broadcast() {
        NotificationCenter.default.post(name: .serviceStatusDidChange, object: nil)
        // Can remove DistributedNotificationCenter if the settings UI moves in-process
        DistributedNotificationCenter.default().post(name: .serviceStatusDidChange, object: nil)
    }
}
