import Foundation

/// Dosya sekmelerinin henüz dosyaya yazılmamış değişiklikleri: pending/<sekme id>.txt
public struct PendingStore {
    public let dir: URL

    public init(dir: URL) {
        self.dir = dir
    }

    private func url(_ id: UUID) -> URL {
        dir.appending(path: "\(id.uuidString).txt")
    }

    public func save(_ text: String, for id: UUID) throws {
        try TextFile.write(text, to: url(id))
    }

    public func load(_ id: UUID) -> String? {
        try? TextFile.read(url(id))
    }

    public func remove(_ id: UUID) {
        try? FileManager.default.removeItem(at: url(id))
    }
}
