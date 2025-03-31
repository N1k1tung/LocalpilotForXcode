import Foundation
import XcodeKit

class SyncTextSettingsCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Sync Text Settings" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            let service = try getService()
            _ = try await service.getRealtimeSuggestedCode(editorContent: .init(invocation))
        }
    }
}
