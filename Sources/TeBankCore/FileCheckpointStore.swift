import Foundation

public enum CheckpointReadError: Error, Equatable, Sendable {
    case corrupt
    case unsupportedVersion(Int)
}

public protocol CheckpointStore: Sendable {
    func load() async throws -> OnboardingCheckpoint?
    func save(_ checkpoint: OnboardingCheckpoint) async throws
}

/// Share one instance per file to serialize access within the app process.
public actor FileCheckpointStore: CheckpointStore {
    private struct Header: Decodable {
        let version: Int
    }

    private struct Record: Codable {
        let version: Int
        let checkpoint: OnboardingCheckpoint
    }

    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() throws -> OnboardingCheckpoint? {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }

        let decoder = JSONDecoder()
        do {
            let header = try decoder.decode(Header.self, from: data)
            guard header.version == OnboardingCheckpoint.schemaVersion else {
                throw CheckpointReadError.unsupportedVersion(header.version)
            }
            return try decoder.decode(Record.self, from: data).checkpoint
        } catch is DecodingError {
            throw CheckpointReadError.corrupt
        }
    }

    public func save(_ checkpoint: OnboardingCheckpoint) throws {
        let record = Record(version: OnboardingCheckpoint.schemaVersion, checkpoint: checkpoint)
        let data = try JSONEncoder().encode(record)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}
