import AppKit
import CGEventOverride
import Foundation
import Combine
import CombineBinding

final class TabToAcceptSuggestion {
    let hook: CGEventHookType = CGEventHook(eventsOfInterest: [.keyDown]) { message in
        dprint("TabToAcceptSuggestion: \(message)")
    }

    let workspacePool: WorkspacePool
    let acceptSuggestion: () -> Void
    let expandSuggestion: () -> Void
    let collapseSuggestion: () -> Void
    let dismissSuggestion: () -> Void
    private var modifierEventMonitor: Any?
    private var stoppedForExit = false

    struct ObservationKey: Hashable {}

    @MainActor
    func stopForExit() {
        stoppedForExit = true
        stopObservation()
    }

    init(
        workspacePool: WorkspacePool,
        acceptSuggestion: @escaping () -> Void,
        dismissSuggestion: @escaping () -> Void,
        expandSuggestion: @escaping () -> Void,
        collapseSuggestion: @escaping () -> Void
    ) {
        _ = ThreadSafeAccessToXcodeInspector.shared
        self.workspacePool = workspacePool
        self.acceptSuggestion = acceptSuggestion
        self.dismissSuggestion = dismissSuggestion
        self.expandSuggestion = expandSuggestion
        self.collapseSuggestion = collapseSuggestion

        hook.add(
            .init(
                eventsOfInterest: [.keyDown],
                convert: { [weak self] _, _, event in
                    self?.handleEvent(event) ?? .unchanged
                }
            ),
            forKey: ObservationKey()
        )
    }

    func start() {
        Task { [weak self] in
            for await _ in ActiveApplicationMonitor.shared.createInfoStream() {
                guard let self else { return }
                try Task.checkCancellation()
                Task { @MainActor in
                    if ActiveApplicationMonitor.shared.activeXcode != nil {
                        self.startObservation()
                    } else {
                        self.stopObservation()
                    }
                }
            }
        }
    }

    @MainActor
    func startObservation() {
        guard !stoppedForExit else { return }
        hook.activateIfPossible()
        removeMonitor()
        modifierEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleModifierEvents(event: event)
        }
    }

    @MainActor
    func stopObservation() {
        hook.deactivate()
        removeMonitor()
    }

    private func removeMonitor() {
        if let monitor = modifierEventMonitor {
            NSEvent.removeMonitor(monitor)
            modifierEventMonitor = nil
        }
    }

    func handleEvent(_ event: CGEvent) -> CGEventManipulation.Result {
        let (accept, reason) = Self.shouldAcceptSuggestion(
            event: event,
            workspacePool: workspacePool,
            xcodeInspector: ThreadSafeAccessToXcodeInspector.shared
        )
        if let reason = reason {
            dprint("TabToAcceptSuggestion: \(accept ? "" : "not") accepting due to: \(reason)")
        }
        if accept {
            acceptSuggestion()
            return .discarded
        }
        return .unchanged
    }

    func handleModifierEvents(event: NSEvent) {
        if event.modifierFlags.contains(NSEvent.ModifierFlags.option) {
            expandSuggestion()
        } else {
            collapseSuggestion()
        }
    }
}

extension TabToAcceptSuggestion {
    /// Returns whether a given keyboard event should be intercepted and trigger
    /// accepting a suggestion.
    static func shouldAcceptSuggestion(
        event: CGEvent,
        workspacePool: WorkspacePool,
        xcodeInspector: ThreadSafeAccessToXcodeInspectorProtocol
    ) -> (accept: Bool, reason: String?) {
        let keycode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let tab = 48
        guard keycode == tab else { return (false, nil) }
        if event.flags.contains(.maskHelp) { return (false, nil) }
        if event.flags.contains(.maskShift) { return (false, nil) }
        if event.flags.contains(.maskControl) { return (false, nil) }
        if event.flags.contains(.maskCommand) { return (false, nil) }
        guard xcodeInspector.hasActiveXcode else {
            return (false, "No active Xcode")
        }
        guard xcodeInspector.hasFocusedEditor else {
            return (false, "No focused editor")
        }
        guard let fileURL = xcodeInspector.activeDocumentURL else {
            return (false, "No active document")
        }
        guard let filespace = workspacePool.fetchFilespaceIfExisted(fileURL: fileURL) else {
            return (false, "No filespace")
        }
        if filespace.presentingSuggestion == nil {
            return (false, "No suggestion")
        }
        return (true, nil)
    }
}

protocol ThreadSafeAccessToXcodeInspectorProtocol {
    var activeDocumentURL: URL? {get}
    var hasActiveXcode: Bool {get}
    var hasFocusedEditor: Bool {get}
}

private class ThreadSafeAccessToXcodeInspector: ThreadSafeAccessToXcodeInspectorProtocol, HasCancellables {
    static let shared = ThreadSafeAccessToXcodeInspector()

    private(set) var activeDocumentURL: URL?
    private(set) var hasActiveXcode = false
    private(set) var hasFocusedEditor = false
    var cancellables: Set<AnyCancellable> = []

    init() {
        let inspector = XcodeInspector.shared

        bind {
            inspector.$activeDocumentURL ~> { [weak self] newValue in
                self?.activeDocumentURL = newValue
            }
            inspector.$activeXcode ~> { [weak self] newValue in
                self?.hasActiveXcode = newValue != nil
            }
            inspector.$focusedEditor ~> { [weak self] newValue in
                self?.hasFocusedEditor = newValue != nil
            }
        }
    }
}
