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

    public func load() throws -> LocalTransfer? {
        do {
            let data = try Data(contentsOf: file)
            return try JSONDecoder().decode(LocalTransfer.self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }
    }
}
