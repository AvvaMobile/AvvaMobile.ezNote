import AppKit
import NotepadCore

/// Her sekmeye ayrı bir NSTextView (geri al geçmişi ve imleç sekmede kalsın); yalnız seçili olan görünür.
final class EditorView: NSView {
    weak var textDelegate: NSTextViewDelegate?
    private var views: [UUID: NSScrollView] = [:]
    private var font: NSFont

    init(font: FontSettings) {
        self.font = Self.nsFont(font)
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    func textView(for id: UUID) -> NSTextView? {
        views[id]?.documentView as? NSTextView
    }

    func id(of textView: NSTextView) -> UUID? {
        views.first { $0.value.documentView === textView }?.key
    }

    /// Kapanan sekmelerin görünümlerini atar, yenilerini açar, seçiliyi gösterir; metni dışarıdan değişeni günceller.
    func sync(tabs: [TabDocument], activeID: UUID?) {
        let ids = Set(tabs.map(\.id))
        for (id, view) in views where !ids.contains(id) {
            view.removeFromSuperview()
            views[id] = nil
        }
        for doc in tabs {
            let scroll = views[doc.id] ?? makeScrollView(for: doc.id)
            let textView = scroll.documentView as! NSTextView
            if textView.string != doc.text {
                textView.string = doc.text
            }
            scroll.isHidden = doc.id != activeID
        }
    }

    func apply(_ settings: FontSettings) {
        font = Self.nsFont(settings)
        for view in views.values {
            guard let textView = view.documentView as? NSTextView else { continue }
            textView.font = font
            textView.typingAttributes[.font] = font
        }
    }

    static func nsFont(_ settings: FontSettings) -> NSFont {
        let size = CGFloat(settings.size)
        if let family = settings.family,
           let font = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size) {
            return font
        }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    private func makeScrollView(for id: UUID) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.borderType = .noBorder
        let textView = scroll.documentView as! NSTextView
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.font = font
        textView.typingAttributes[.font] = font
        textView.delegate = textDelegate

        addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        views[id] = scroll
        return scroll
    }
}
