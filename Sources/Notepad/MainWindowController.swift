import AppKit
import NotepadCore

final class MainWindowController: NSWindowController, NSTextViewDelegate, NSWindowDelegate {
    let workspace: Workspace
    private let tabBar = TabBarView()
    let editor: EditorView
    private var shownActiveID: UUID?
    private var autosaveID: UUID?
    var saveErrorPresenter: (Error) -> Void = { showError("Couldn’t Save", $0) }
    private var saveErrorShown = false

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
        // Kendi sekme çubuğumuz var; macOS'un pencere sekmeleri ikinci bir çubuk açmasın.
        window.tabbingMode = .disallowed
        super.init(window: window)

        if !window.setFrameUsingName("MainWindow") { window.center() }
        window.setFrameAutosaveName("MainWindow")
        layout(in: window)
        window.delegate = self

        editor.textDelegate = self
        editor.onOpenFiles = { [weak self] in self?.openFiles($0) }
        tabBar.onSelect = { [weak self] in self?.workspace.select($0) }
        tabBar.onClose = { [weak self] in self?.closeTab($0) }
        tabBar.onNew = { [weak self] in self?.newTabAction(nil) }
        tabBar.onMove = { [weak self] in self?.workspace.move($0, to: $1) }
        workspace.onChange = { [weak self] in self?.sync() }
        sync()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func layout(in window: NSWindow) {
        let content = FileDropView()
        content.onOpenFiles = { [weak self] in self?.openFiles($0) }
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
            flushReporting(previous)
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

    /// Ana pencereyi kapatmak uygulamadan çıkmak demek (Ayarlar penceresi açık kalsa bile).
    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }

    /// Her sekmeye ayrı geri al geçmişi; yoksa ⌘Z gizli sekmedeki metni siler.
    func undoManager(for view: NSTextView) -> UndoManager? {
        editor.id(of: view).map(editor.undoManager(for:))
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView, let id = editor.id(of: textView) else { return }
        workspace.updateText(id, textView.string)
        scheduleAutosave(id)
    }

    /// Yazma 1 sn durunca kaydeder.
    private func scheduleAutosave(_ id: UUID) {
        if let previous = autosaveID, previous != id { flushReporting(previous) }
        autosaveID = id
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(autosave), object: nil)
        perform(#selector(autosave), with: nil, afterDelay: 1)
    }

    @objc private func autosave() {
        guard let id = autosaveID else { return }
        autosaveID = nil
        flushReporting(id)
    }

    /// Yazma hatasını gösterir; her saniye uyarı çıkmasın diye bir kayıt başarılı olana kadar bir kez.
    func flushReporting(_ id: UUID) {
        do {
            try workspace.flush(id)
            saveErrorShown = false
        } catch {
            guard !saveErrorShown else { return }
            saveErrorShown = true
            saveErrorPresenter(error)
        }
    }

    /// Çıkışta her şeyi yazar; yazılamayan bir şey olursa hatayı döner.
    func flushAll() -> Error? {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(autosave), object: nil)
        autosaveID = nil
        do {
            try workspace.flushAll()
            return nil
        } catch {
            return error
        }
    }

    /// Boş temp not ve değişmemiş dosya sorusuz kapanır; diğerlerinde kaydet/sil sorulur.
    func closeTab(_ id: UUID) {
        guard let doc = workspace.tab(id) else { return }
        switch workspace.closeAction(for: id) {
        case .closeSilently:
            attempt { try workspace.close(id, discard: true) }
        case .askTemp:
            workspace.select(id)
            ask("Do you want to save this note?", info: "Delete moves the note to the Trash.", buttons: ["Save", "Delete", "Cancel"]) { [self] choice in
                switch choice {
                case 0: saveTab(id, forcePanel: true) { [self] in attempt { try workspace.close(id, discard: true) } }
                case 1: attempt { try workspace.close(id, discard: true) }
                default: break
                }
            }
        case .askFile:
            workspace.select(id)
            ask("Do you want to save the changes made to \"\(doc.kind.url.lastPathComponent)\"?", info: "", buttons: ["Save", "Don’t Save", "Cancel"]) { [self] choice in
                switch choice {
                case 0: saveTab(id, forcePanel: false) { [self] in attempt { try workspace.close(id, discard: true) } }
                case 1: attempt { try workspace.close(id, discard: true) }
                default: break
                }
            }
        }
    }

    /// Üç düğmeli soru; ikinci düğme yıkıcı, üçüncü Esc ile seçilir. `done` seçilen düğmenin sırasını alır.
    private func ask(_ title: String, info: String, buttons: [String], done: @escaping (Int) -> Void) {
        guard let window else { return }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        buttons.forEach { alert.addButton(withTitle: $0) }
        alert.buttons[1].hasDestructiveAction = true
        alert.buttons[2].keyEquivalent = "\u{1b}"
        alert.beginSheetModal(for: window) { response in
            let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
            // Kaydet paneli de sheet; uyarı sheet'i tamamen kapanınca açılsın.
            DispatchQueue.main.async { done(index) }
        }
    }

    /// Konum gerekiyorsa (ya da Farklı Kaydet ise) panel açar; başarıyla kaydedilirse `then` çalışır.
    private func saveTab(_ id: UUID, forcePanel: Bool, then: (() -> Void)? = nil) {
        guard let doc = workspace.tab(id) else { return }
        guard forcePanel || workspace.needsSavePanel(id) else {
            if attempt("Couldn’t Save", { try workspace.save(id) }) { then?() }
            return
        }
        guard let window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText, .json]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedFileName(doc)
        panel.beginSheetModal(for: window) { [self] response in
            guard response == .OK, let url = panel.url else { return }
            if attempt("Couldn’t Save", { try workspace.saveAs(id, to: url) }) { then?() }
        }
    }

    private func suggestedFileName(_ doc: TabDocument) -> String {
        if !doc.kind.isTemp { return doc.kind.url.lastPathComponent }
        let name = doc.title.replacingOccurrences(of: "…", with: "")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return name + ".txt"
    }

    /// Hata olursa kullanıcıya gösterir.
    @discardableResult
    func attempt(_ title: String = "Couldn’t Save", _ work: () throws -> Void) -> Bool {
        do {
            try work()
            return true
        } catch {
            showError(title, error)
            return false
        }
    }

    @objc func newTabAction(_ sender: Any?) {
        attempt("Couldn’t Open a New Tab") { try workspace.newTab() }
    }

    @objc func closeTabAction(_ sender: Any?) {
        if let id = workspace.activeID { closeTab(id) }
    }

    @objc func saveAction(_ sender: Any?) {
        if let id = workspace.activeID { saveTab(id, forcePanel: false) }
    }

    @objc func saveAsAction(_ sender: Any?) {
        if let id = workspace.activeID { saveTab(id, forcePanel: true) }
    }

    @objc func openAction(_ sender: Any?) {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.delegate = TextFilePanelFilter.shared
        panel.allowsMultipleSelection = true
        panel.beginSheetModal(for: window) { [self] response in
            guard response == .OK else { return }
            let urls = panel.urls
            // Uyarı gerekirse panel kapandıktan sonra çıksın.
            DispatchQueue.main.async { [self] in urls.forEach(open) }
        }
    }

    /// Sürükle-bırak ve Dock'tan gelenler; yalnız metin dosyaları açılır.
    func openFiles(_ urls: [URL]) {
        FileDrop.textFiles(urls).forEach(open)
    }

    private func open(_ url: URL) {
        do {
            try workspace.open(url)
        } catch TextFileError.notUTF8 {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "This file can’t be opened"
            alert.informativeText = "\(AppInfo.name) can only open UTF-8 plain text files."
            alert.runModal()
        } catch {
            showError("This file can’t be opened", error)
        }
    }
}
