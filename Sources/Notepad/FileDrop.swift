import AppKit

/// Finder'dan sürüklenen dosyalardan yalnız .txt olanlar açılır.
enum FileDrop {
    static func textFiles(on pasteboard: NSPasteboard) -> [URL] {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return textFiles(urls)
    }

    static func textFiles(_ urls: [URL]) -> [URL] {
        urls.filter { $0.pathExtension.lowercased() == "txt" }
    }

    /// İçinde .txt varsa bırakmayı kabul eder; yoksa `nil` (görünüm kendi davranışına bırakır).
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

/// Editör: .txt bırakılınca dosyayı açar; diğer bırakmalar NSTextView'a kalır (yolu metne yazar).
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
