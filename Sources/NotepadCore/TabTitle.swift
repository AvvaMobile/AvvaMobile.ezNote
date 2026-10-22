import Foundation

public enum TabTitle {
    static let maxLength = 30

    /// Dosya sekmesinde dosya adı; temp notta ilk satır (30 karakter), ilk satır boşsa "Adsız N".
    public static func make(text: String, kind: TabKind, untitledNumber: Int) -> String {
        if case .file(let url) = kind { return url.lastPathComponent }
        let firstLine = text.prefix { !$0.isNewline }.trimmingCharacters(in: .whitespaces)
        if firstLine.isEmpty { return "Adsız \(untitledNumber)" }
        return firstLine.count > maxLength ? firstLine.prefix(maxLength) + "…" : firstLine
    }
}
