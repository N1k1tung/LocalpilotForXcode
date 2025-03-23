import Foundation

public final class OpenedFileRecoverableStorage {
    let projectRootURL: URL

    @UserDefaultsKey(key: "OpenedFileRecoverableStorage")
    var storage: [String: Any]?

    init(projectRootURL: URL) {
        self.projectRootURL = projectRootURL
    }

    public func openFile(fileURL: URL) {
        var dict = storage ?? [:]
        var openedFiles = Set(dict[projectRootURL.path] as? [String] ?? [])
        openedFiles.insert(fileURL.path)
        dict[projectRootURL.path] = Array(openedFiles)
        Task { @MainActor [dict] in
            storage = dict
        }
    }

    public func closeFile(fileURL: URL) {
        var dict = storage ?? [:]
        var openedFiles = dict[projectRootURL.path] as? [String] ?? []
        openedFiles.removeAll(where: { $0 == fileURL.path })
        dict[projectRootURL.path] = openedFiles
        Task { @MainActor [dict] in
            storage = dict
        }
    }

    public var openedFiles: [URL] {
        let dict = storage ?? [:]
        let openedFiles = dict[projectRootURL.path] as? [String] ?? []
        return openedFiles.map { URL(fileURLWithPath: $0) }
    }
}

