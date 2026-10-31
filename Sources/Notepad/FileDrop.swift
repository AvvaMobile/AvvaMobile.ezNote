import AppKit
import UniformTypeIdentifiers

/// Finder'dan sürüklenen dosyalardan yalnız metin olanlar açılır.
enum FileDrop {
    /// Türü tanınmayan dosyada içeriğin bu kadar baytına bakılır.
    static let sniffLength = 8192

    static func textFiles(on pasteboard: NSPasteboard) -> [URL] {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return textFiles(urls)
    }

    static func textFiles(_ urls: [URL]) -> [URL] {
        urls.filter(isText)
    }

    /// Uzantı metin türündense metindir (RTF hariç); tanınmazsa içerik UTF-8 ve boş baytsız mı diye bakılır.
    static func isText(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else { return false }
        if let type = UTType(filenameExtension: url.pathExtension) {
            if type.conforms(to: .rtf) { return false }
            if type.conforms(to: .text) { return true }
        }
        return hasTextContent(url)
    }

    private static func hasTextContent(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: sniffLength + 3), !data.isEmpty else { return true }
        if data.contains(0) { return false }
        // Sınırda bölünmüş çok baytlı karakter yüzünden reddetmemek için sondan 3 bayta kadar kırpılarak denenir.
        let head = data.prefix(sniffLength)
        let cuts = data.count > sniffLength ? 0...3 : 0...0
        return cuts.contains { String(data: head.dropLast($0), encoding: .utf8) != nil }
    }

    /// İçinde açılabilir dosya varsa bırakmayı kabul eder; yoksa `nil` (görünüm kendi davranışına bırakır).
    static func operation(for sender: NSDraggingInfo) -> NSDragOperation? {
        textFiles(on: sender.draggingPasteboard).isEmpty ? nil : .copy
    }
}

/// Sekme çubuğu ve pencerenin boş yerleri için bırakma alanı.
final class FileDropView: NSView {
    var onOpenFiles: (([URL]) -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        FileDrop.operation(for: sender) ?? []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onOpenFiles?(FileDrop.textFiles(on: sender.draggingPasteboard))
        return true
    }
}

/// Editör: metin dosyası bırakılınca dosyayı açar; diğer bırakmalar NSTextView'a kalır (yolu metne yazar).
final class FileDropTextView: NSTextView {
    var onOpenFiles: (([URL]) -> Void)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        FileDrop.operation(for: sender) ?? super.draggingEntered(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        FileDrop.operation(for: sender) ?? super.draggingUpdated(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = FileDrop.textFiles(on: sender.draggingPasteboard)
        guard !urls.isEmpty else { return super.performDragOperation(sender) }
        onOpenFiles?(urls)
        return true
    }
}
