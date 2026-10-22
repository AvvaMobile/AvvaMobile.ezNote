import Foundation

public enum TextFileError: Error, Equatable {
    case notUTF8
}

/// Düz metin dosyaları yalnız UTF-8 okunur ve yazılır.
public enum TextFile {
    public static func read(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else { throw TextFileError.notUTF8 }
        return text
    }

    public static func write(_ text: String, to url: URL) throws {
        try Data(text.utf8).write(to: url, options: .atomic)
    }
}

extension URL {
    /// Aynı dosyayı gösteren iki URL'yi karşılaştırmak için (ör. /var ve /private/var).
    var canonical: URL { standardizedFileURL.resolvingSymlinksInPath() }
}
