import Foundation

/// Açık bir sekme: metni, bağlı olduğu dosya ve dosyaya yazılmamış değişiklik olup olmadığı.
public final class TabDocument {
    public let id: UUID
    public var kind: TabKind
    public var text: String
    /// Yalnız dosya sekmelerinde anlamlı; temp notlar zaten otomatik kaydedilir.
    public var isDirty: Bool
    public var untitledNumber: Int
    /// Dosyanın son okunduğu ya da yazıldığı andaki değişiklik tarihi; dışarıdan değişikliği fark etmek için.
    public var fileModDate: Date?

    public var title: String {
        TabTitle.make(text: text, kind: kind, untitledNumber: untitledNumber)
    }

    public init(id: UUID = UUID(), kind: TabKind, text: String, isDirty: Bool = false, untitledNumber: Int = 1, fileModDate: Date? = nil) {
        self.id = id
        self.kind = kind
        self.text = text
        self.isDirty = isDirty
        self.untitledNumber = untitledNumber
        self.fileModDate = fileModDate
    }
}
