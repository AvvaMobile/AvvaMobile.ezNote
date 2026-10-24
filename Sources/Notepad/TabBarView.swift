import AppKit

/// Pencerenin üstünde hep görünen sekme çubuğu: her sekmede ad ve "x", en sonda "+".
/// Sekme sürüklenince diğerleri kayarak yer açar; bırakınca `onMove` yeni sırayı bildirir.
final class TabBarView: NSView {
    static let tabWidth: CGFloat = 180
    static let spacing: CGFloat = 2
    static let leftInset: CGFloat = 6

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
    private let stack = NSStackView()
    private var items: [Item] = []
    private var activeID: UUID?

    override init(frame: NSRect) {
        super.init(frame: frame)
        stack.orientation = .horizontal
        stack.spacing = Self.spacing
        stack.edgeInsets = NSEdgeInsets(top: 4, left: Self.leftInset, bottom: 0, right: Self.leftInset)
        stack.alignment = .bottom
        stack.translatesAutoresizingMaskIntoConstraints = false

        scroll.drawsBackground = false
        scroll.hasHorizontalScroller = false
        scroll.hasVerticalScroller = false
        scroll.documentView = stack
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.contentView.heightAnchor),
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
        let plus = NSButton(image: NSImage(systemSymbolName: "plus", accessibilityDescription: "New Tab")!, target: self, action: #selector(newTab))
        plus.isBordered = false
        plus.toolTip = "New Tab"
        stack.addArrangedSubview(plus)
        plus.centerYAnchor.constraint(equalTo: stack.centerYAnchor, constant: 2).isActive = true

        layoutSubtreeIfNeeded()
        if let active = stack.arrangedSubviews.first(where: { ($0 as? TabItemView)?.isActive == true }) {
            active.scrollToVisible(active.bounds)
        }
    }

    @objc private func newTab() {
        onNew?()
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

private final class TabItemView: NSView {
    var onMouseDown: ((NSEvent) -> Void)?
    var onClose: (() -> Void)?
    let id: UUID
    let isActive: Bool

    init(item: TabBarView.Item, isActive: Bool) {
        id = item.id
        self.isActive = isActive
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
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

    override func updateLayer() {
        layer?.backgroundColor = isActive ? NSColor.textBackgroundColor.cgColor : NSColor.clear.cgColor
    }

    override var wantsUpdateLayer: Bool { true }

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
