import Foundation

/// Notlar klasöründeki temp notlar: "Note 2026-10-22 14.30.05.txt", çakışmada " 2", " 3" eki.
/// Türkçe sürümün "Not ..." adlı eski notları da temp sayılır.
public struct TempNoteStore {
    public let dir: URL
    private let trash: (URL) throws -> Void

    public init(dir: URL, trash: @escaping (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }) {
        self.dir = dir
        self.trash = trash
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return f
    }()

    private static let namePattern = try! Regex(#"^Note? \d{4}-\d{2}-\d{2} \d{2}\.\d{2}\.\d{2}( \d+)?\.txt$"#)

    public func create(now: Date) throws -> URL {
        let base = "Note \(Self.formatter.string(from: now))"
        var url = dir.appending(path: "\(base).txt")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = dir.appending(path: "\(base) \(n).txt")
            n += 1
        }
        try Data().write(to: url, options: .withoutOverwriting)
        return url
    }

    public func isTempName(_ fileName: String) -> Bool {
        fileName.wholeMatch(of: Self.namePattern) != nil
    }

    /// Klasörde olup `known` içinde olmayan temp notlar, ada (yani zamana) göre sıralı.
    public func orphans(excluding known: Set<URL>) -> [URL] {
        let knownPaths = Set(known.map(\.canonical.path))
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { isTempName($0.lastPathComponent) && !knownPaths.contains($0.canonical.path) }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    public func deletePermanently(_ url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    public func moveToTrash(_ url: URL) throws {
        try trash(url)
    }
}
