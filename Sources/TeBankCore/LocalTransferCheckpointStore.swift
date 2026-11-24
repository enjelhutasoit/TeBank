import Foundation

/// Stores one reviewed transfer. Submission state belongs to the SDK journal.
public struct LocalTransferCheckpointStore: Sendable {
    private let file: URL

    public init(directory: URL) {
        file = directory.appendingPathComponent("reviewed-transfer.json")
    }

    public func save(_ transfer: LocalTransfer) throws {
        let data = try JSONEncoder().encode(transfer)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: file, options: .atomic)
    }

    /// Retires the active checkpoint into history in the same storage directory.
    public func archive(_ reviewed: LocalTransfer) throws {
        guard try load() == reviewed else { throw ArchiveError.checkpointMismatch }
        let history = file.deletingLastPathComponent().appendingPathComponent("history", isDirectory: true)
        try FileManager.default.createDirectory(at: history, withIntermediateDirectories: true)
        let destination = history.appendingPathComponent(reviewed.id.uuidString).appendingPathExtension("json")
        try FileManager.default.moveItem(at: file, to: destination)
    }

    public func archivedTransfers() throws -> [LocalTransfer] {
        let history = file.deletingLastPathComponent().appendingPathComponent("history", isDirectory: true)
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(at: history, includingPropertiesForKeys: nil)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        }
        let decoder = JSONDecoder()
        let transfers = try files.filter { $0.pathExtension == "json" }.map { url in
            let transfer = try decoder.decode(LocalTransfer.self, from: Data(contentsOf: url))
            guard url.deletingPathExtension().lastPathComponent == transfer.id.uuidString else {
                throw ArchiveError.checkpointMismatch
            }
            return transfer
        }
        return transfers.sorted {
            if $0.beneficiary != $1.beneficiary { return $0.beneficiary < $1.beneficiary }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    public enum ArchiveError: Error {
        case checkpointMismatch
    }

    public func clear() throws {
        do {
            try FileManager.default.removeItem(at: file)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        }
    }

    public func load() throws -> LocalTransfer? {
        do {
            let data = try Data(contentsOf: file)
            return try JSONDecoder().decode(LocalTransfer.self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
    }
}
