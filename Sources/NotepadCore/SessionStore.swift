import Foundation

public struct SessionStore {
    public let file: URL

    public init(file: URL) {
        self.file = file
    }

    /// Dosya yoksa ya da bozuksa nil; uygulama yine de açılır.
    public func load() -> Session? {
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    public func save(_ session: Session) throws {
        try JSONEncoder().encode(session).write(to: file, options: .atomic)
    }
}
