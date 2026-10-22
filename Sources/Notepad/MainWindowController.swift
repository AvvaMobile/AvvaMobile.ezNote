import AppKit
import NotepadCore

final class MainWindowController: NSWindowController, NSTextViewDelegate {
    let workspace: Workspace
    private let tabBar = TabBarView()
    let editor: EditorView
    private var shownActiveID: UUID?
    private var autosaveID: UUID?

    init(workspace: Workspace, font: FontSettings) {
        self.workspace = workspace
        editor = EditorView(font: font)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = AppInfo.name
        window.minSize = NSSize(width: 400, height: 250)
        super.init(window: window)

        if !window.setFrameUsingName("MainWindow") { window.center() }
        window.setFrameAutosaveName("MainWindow")
        layout(in: window)

        editor.textDelegate = self
        tabBar.onSelect = { [weak self] in self?.workspace.select($0) }
        tabBar.onClose = { [weak self] in self?.closeTab($0) }
        tabBar.onNew = { [weak self] in self?.newTabAction(nil) }
        workspace.onChange = { [weak self] in self?.sync() }
        sync()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func layout(in window: NSWindow) {
        let content = NSView()
        for view in [tabBar, editor] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            tabBar.topAnchor.constraint(equalTo: content.topAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 32),
            editor.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            editor.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            editor.topAnchor.constraint(equalTo: tabBar.bottomAnchor),
            editor.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window.contentView = content
    }

    /// Workspace değişince sekme çubuğunu ve editörü günceller; sekme değiştiyse eskisini hemen kaydeder.
    private func sync() {
        let activeID = workspace.activeID
        if let previous = shownActiveID, previous != activeID {
            try? workspace.flush(previous)
        }
        tabBar.update(
            items: workspace.tabs.map { .init(id: $0.id, title: $0.title, isDirty: $0.isDirty) },
            activeID: activeID
        )
        editor.sync(tabs: workspace.tabs, activeID: activeID)
        if shownActiveID != activeID, let id = activeID, let textView = editor.textView(for: id) {
            window?.makeFirstResponder(textView)
        }
        shownActiveID = activeID
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView, let id = editor.id(of: textView) else { return }
        workspace.updateText(id, textView.string)
        scheduleAutosave(id)
    }

    /// Yazma 1 sn durunca kaydeder.
    private func scheduleAutosave(_ id: UUID) {
        if let previous = autosaveID, previous != id { try? workspace.flush(previous) }
        autosaveID = id
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(autosave), object: nil)
        perform(#selector(autosave), with: nil, afterDelay: 1)
    }

    @objc private func autosave() {
        guard let id = autosaveID else { return }
        autosaveID = nil
        try? workspace.flush(id)
    }

    func flushAll() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(autosave), object: nil)
        autosaveID = nil
        try? workspace.flushAll()
    }

    func closeTab(_ id: UUID) {
        guard workspace.closeAction(for: id) == .closeSilently else {
            NSSound.beep()
            return
        }
        attempt { try workspace.close(id, discard: true) }
    }

    /// Hata olursa kullanıcıya gösterir.
    func attempt(_ title: String = "Kaydedilemedi", _ work: () throws -> Void) {
        do { try work() } catch { showError(title, error) }
    }

    @objc func newTabAction(_ sender: Any?) {
        attempt("Yeni sekme açılamadı") { try workspace.newTab() }
    }

    @objc func closeTabAction(_ sender: Any?) {
        if let id = workspace.activeID { closeTab(id) }
    }
}
