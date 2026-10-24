import AppKit

/// Pencerenin üstünde hep görünen sekme çubuğu: her sekmede ad ve "x", en sonda "+".
final class TabBarView: NSView {
    struct Item: Equatable {
        let id: UUID
        let title: String
        let isDirty: Bool
    }

    var onSelect: ((UUID) -> Void)?
    var onClose: ((UUID) -> Void)?
    var onNew: (() -> Void)?

    private let scroll = NSScrollView()
    private let stack = NSStackView()
    private var items: [Item] = []
    private var activeID: UUID?

    override init(frame: NSRect) {
        super.init(frame: frame)
        stack.orientation = .horizontal
        stack.spacing = 2
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 6, bottom: 0, right: 6)
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
            tab.onSelect = { [weak self] in self?.onSelect?(item.id) }
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
}

private final class TabItemView: NSView {
    var onSelect: (() -> Void)?
    var onClose: (() -> Void)?
    let isActive: Bool

    init(item: TabBarView.Item, isActive: Bool) {
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
            widthAnchor.constraint(equalToConstant: 180),
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
        onSelect?()
    }

    @objc private func closeTapped() {
        onClose?()
    }
}
