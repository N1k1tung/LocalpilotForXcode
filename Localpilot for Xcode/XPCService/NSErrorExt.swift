import Foundation
import LanguageServerProtocol

extension NSError {
    static func from(_ error: Error) -> NSError {
        if let error = error as? CancellationError {
            return NSError(domain: "com.n1k1tung.locapilot", code: -100, userInfo: [
                NSLocalizedDescriptionKey: error.localizedDescription,
            ])
        }
        return NSError(domain: "com.n1k1tung.locapilot", code: -1, userInfo: [
            NSLocalizedDescriptionKey: error.localizedDescription,
        ])
    }
}
