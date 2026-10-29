import AppKit

/// Pencerenin üstünde hep görünen sekme çubuğu: her sekmede ad ve "x", en sonda "+".
/// Sekme sürüklenince diğerleri kayarak yer açar; bırakınca `onMove` yeni sırayı bildirir.
final class TabBarView: NSView {
    static let tabWidth: CGFloat = 180
    static let spacing: CGFloat = 2
    static let leftInset: CGFloat = 6
    static let plusGap: CGFloat = 6

    static func slotOrigin(_ index: Int) -> CGFloat {
        leftInset + CGFloat(index) * (tabWidth + spacing)
    }

    /// Sürüklenen sekmenin ortası (çubuk içeriğine göre) hangi sıraya düşüyor.
    static func dropIndex(centerX: CGFloat, count: Int) -> Int {
        let slot = Int(((centerX - leftInset) / (tabWidth + spacing)).rounded(.down))
        return min(max(slot, 0), count - 1)
    }

    struct Item: Equatable {
        let id: UUID
        let title: String
        let isDirty: Bool
    }

    var onSelect: ((UUID) -> Void)?
    var onClose: ((UUID) -> Void)?
    var onNew: (() -> Void)?
    var onMove: ((UUID, Int) -> Void)?

    private let scroll = NSScrollView()
    private let content = NSView()
    private let stack = NSStackView()
    private let plus = NewTabButton()
    private var items: [Item] = []
    private var activeID: UUID?

    override init(frame: NSRect) {
        super.init(frame: frame)
        stack.orientation = .horizontal
        stack.spacing = Self.spacing
        stack.edgeInsets = NSEdgeInsets(top: 4, left: Self.leftInset, bottom: 0, right: 0)
        stack.alignment = .bottom
        plus.onClick = { [weak self] in self?.onNew?() }

        // "+" yığının dışında durur; sekme sürüklerken sıra hesabına karışmaz, yeniden çizimde hover'ı kaybolmaz.
        for view in [stack, plus] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        content.translatesAutoresizingMaskIntoConstraints = false

        scroll.drawsBackground = false
        scroll.hasHorizontalScroller = false
        scroll.hasVerticalScroller = false
        scroll.documentView = content
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            content.heightAnchor.constraint(equalTo: scroll.contentView.heightAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            plus.leadingAnchor.constraint(equalTo: stack.trailingAnchor, constant: Self.plusGap),
            plus.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -Self.leftInset),
            plus.centerYAnchor.constraint(equalTo: content.centerYAnchor, constant: 2),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    func update(items: [Item], activeID: UUID?) {
        guard items != self.items || activeID != self.activeID else { return }
        self.items = items
        self.activeID = activeID
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for item in items {
            let tab = TabItemView(item: item, isActive: item.id == activeID)
            tab.onMouseDown = { [weak self] event in self?.mouseDown(on: item.id, with: event) }
            tab.onClose = { [weak self] in self?.onClose?(item.id) }
            stack.addArrangedSubview(tab)
        }

        layoutSubtreeIfNeeded()
        if let active = stack.arrangedSubviews.first(where: { ($0 as? TabItemView)?.isActive == true }) {
            active.scrollToVisible(active.bounds)
        }
    }

    /// Sekmeler tıklamayı kendileri alır; buraya yalnız çubuğun boş yerine yapılan tıklamalar düşer.
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { onNew?() }
    }

    private var tabViews: [TabItemView] {
        stack.arrangedSubviews.compactMap { $0 as? TabItemView }
    }

    /// Önce sekmeyi seçer (çubuk yeniden çizilir), fare birkaç nokta kayarsa sürüklemeye geçer.
    private func mouseDown(on id: UUID, with event: NSEvent) {
        onSelect?(id)
        guard let window, let tab = tabViews.first(where: { $0.id == id }) else { return }
        let start = event.locationInWindow
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp { return }
            if abs(next.locationInWindow.x - start.x) > 3 {
                drag(tab, from: start)
                return
            }
        }
    }

    private func drag(_ tab: TabItemView, from start: NSPoint) {
        guard let window, let image = tab.snapshot() else { return }
        let grab = tab.convert(start, from: nil).x
        let ghost = NSImageView(image: image)
        ghost.frame = convert(tab.bounds, from: tab)
        ghost.wantsLayer = true
        ghost.layer?.shadowOpacity = 0.25
        ghost.layer?.shadowRadius = 4
        addSubview(ghost)
        tab.alphaValue = 0
        let count = tabViews.count
        var index = tabViews.firstIndex(of: tab) ?? 0

        while let event = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if event.type == .leftMouseUp { break }
            stack.autoscroll(with: event)
            let x = convert(event.locationInWindow, from: nil).x - grab
            ghost.frame.origin.x = min(max(x, 0), bounds.width - ghost.frame.width)
            let center = stack.convert(NSPoint(x: ghost.frame.midX, y: 0), from: self).x
            let target = Self.dropIndex(centerX: center, count: count)
            guard target != index else { continue }
            index = target
            stack.removeArrangedSubview(tab)
            stack.insertArrangedSubview(tab, at: index)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                context.allowsImplicitAnimation = true
                stack.layoutSubtreeIfNeeded()
            }
        }

        ghost.removeFromSuperview()
        tab.alphaValue = 1
        onMove?(tab.id, index)
    }
}

/// Fare üstüne gelince `isHovered` olur ve yeniden çizilir.
private class HoverView: NSView {
    private(set) var isHovered = false {
        didSet { needsDisplay = true }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect], owner: self))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
    }
}

/// Üstü yuvarlak sekme; aktif olan editörle aynı renktir, diğerleri ince çerçeveyle ayrılır.
private final class TabItemView: HoverView {
    var onMouseDown: ((NSEvent) -> Void)?
    var onClose: (() -> Void)?
    let id: UUID
    let isActive: Bool

    init(item: TabBarView.Item, isActive: Bool) {
        id = item.id
        self.isActive = isActive
        super.init(frame: .zero)
        wantsLayer = true
        toolTip = item.title

        let label = NSTextField(labelWithString: (item.isDirty ? "• " : "") + item.title)
        label.lineBreakMode = .byTruncatingTail
        label.textColor = isActive ? .labelColor : .secondaryLabelColor
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let close = NSButton(image: NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close Tab")!, target: nil, action: nil)
        close.isBordered = false
        close.imageScaling = .scaleProportionallyDown
        close.target = self
        close.action = #selector(closeTapped)

        for view in [label, close] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: TabBarView.tabWidth),
            heightAnchor.constraint(equalToConstant: 28),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            close.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 4),
            close.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            close.centerYAnchor.constraint(equalTo: centerYAnchor),
            close.widthAnchor.constraint(equalToConstant: 16),
            close.heightAnchor.constraint(equalToConstant: 16),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    /// Alt kenar editöre açılır, o yüzden çerçeve yalnız üstte ve yanlarda.
    override func draw(_ dirtyRect: NSRect) {
        let rect = NSRect(x: 0.5, y: 0, width: bounds.width - 1, height: bounds.height - 0.5)
        let radius: CGFloat = 6
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.minY))
        path.appendArc(from: NSPoint(x: rect.minX, y: rect.maxY), to: NSPoint(x: rect.midX, y: rect.maxY), radius: radius)
        path.appendArc(from: NSPoint(x: rect.maxX, y: rect.maxY), to: NSPoint(x: rect.maxX, y: rect.minY), radius: radius)
        path.line(to: NSPoint(x: rect.maxX, y: rect.minY))
        if isActive {
            NSColor.textBackgroundColor.setFill()
            path.fill()
            return
        }
        if isHovered {
            NSColor.quaternaryLabelColor.setFill()
            path.fill()
        }
        NSColor.separatorColor.setStroke()
        path.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?(event)
    }

    func snapshot() -> NSImage? {
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        cacheDisplay(in: bounds, to: rep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }

    @objc private func closeTapped() {
        onClose?()
    }
}

/// En sondaki "+": rahat tıklanacak kadar geniş, üstüne gelince arka planı koyulaşır.
private final class NewTabButton: HoverView {
    var onClick: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 5

        let button = NSButton(image: NSImage(systemSymbolName: "plus", accessibilityDescription: "New Tab")!, target: nil, action: nil)
        button.isBordered = false
        button.toolTip = "New Tab"
        button.target = self
        button.action = #selector(clicked)
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 24),
            heightAnchor.constraint(equalToConstant: 24),
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateLayer() {
        layer?.backgroundColor = isHovered ? NSColor.quaternaryLabelColor.cgColor : NSColor.clear.cgColor
    }

    override var wantsUpdateLayer: Bool { true }

    @objc private func clicked() {
        onClick?()
    }
}
