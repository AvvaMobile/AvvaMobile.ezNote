import Foundation

/// Sekmelerin ve dosyaların tüm mantığı. Arayüz yalnız bunu çağırır, `onChange` ile yeniden çizer.
public final class Workspace {
    public var onChange: (() -> Void)?
    public private(set) var tabs: [TabDocument] = []
    public private(set) var activeID: UUID?

    public var active: TabDocument? { activeID.flatMap(tab) }

    let paths: Paths
    let temps: TempNoteStore
    let pending: PendingStore
    let sessionStore: SessionStore
    private let now: () -> Date

    public init(paths: Paths, now: @escaping () -> Date = Date.init, trash: ((URL) throws -> Void)? = nil) {
        self.paths = paths
        self.now = now
        temps = trash.map { TempNoteStore(dir: paths.notesDir, trash: $0) } ?? TempNoteStore(dir: paths.notesDir)
        pending = PendingStore(dir: paths.pendingDir)
        sessionStore = SessionStore(file: paths.sessionFile)
    }

    public func tab(_ id: UUID) -> TabDocument? {
        tabs.first { $0.id == id }
    }

    /// Önceki oturumu geri açar; oturumda olmayan temp notları sona ekler, hiç sekme kalmazsa boş bir tane açar.
    public func restore() throws {
        try paths.ensureDirectories()
        tabs = []
        let session = sessionStore.load()
        for record in session?.tabs ?? [] {
            switch record.kind {
            case .temp(let url):
                guard let text = try? TextFile.read(url) else { continue }
                add(TabDocument(id: record.id, kind: record.kind, text: text, fileModDate: modDate(url)))
            case .file(let url):
                if let text = pending.load(record.id) {
                    add(TabDocument(id: record.id, kind: record.kind, text: text, isDirty: true, fileModDate: modDate(url)))
                } else if let text = try? TextFile.read(url) {
                    add(TabDocument(id: record.id, kind: record.kind, text: text, fileModDate: modDate(url)))
                }
            }
        }
        for url in temps.orphans(excluding: Set(tabs.map(\.kind.url))) {
            guard let text = try? TextFile.read(url) else { continue }
            add(TabDocument(kind: .temp(url), text: text, fileModDate: modDate(url)))
        }
        if tabs.isEmpty {
            try newTab()
        } else {
            activeID = session?.activeTabID.flatMap(tab)?.id ?? tabs[0].id
            try persistSession()
            onChange?()
        }
    }

    @discardableResult
    public func newTab() throws -> TabDocument {
        let url = try temps.create(now: now())
        let doc = TabDocument(kind: .temp(url), text: "", fileModDate: modDate(url))
        add(doc)
        activeID = doc.id
        try persistSession()
        onChange?()
        return doc
    }

    public func select(_ id: UUID) {
        guard tab(id) != nil, id != activeID else { return }
        activeID = id
        try? persistSession()
        onChange?()
    }

    public func updateText(_ id: UUID, _ text: String) {
        guard let doc = tab(id) else { return }
        doc.text = text
        doc.needsFlush = true
        if !doc.kind.isTemp { doc.isDirty = true }
        onChange?()
    }

    /// Yazılmamış metni yazar: temp notu dosyasına, değişmiş dosya sekmesini bekleyen değişikliklere.
    /// Dokunulmamış temp nota yazılmaz; başka bir uygulamada yapılan değişikliği ezmesin.
    public func flush(_ id: UUID) throws {
        guard let doc = tab(id), doc.needsFlush else { return }
        switch doc.kind {
        case .temp(let url):
            // Notlar klasörü uygulama açıkken silinmiş ya da taşınmış olabilir.
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try TextFile.write(doc.text, to: url)
            doc.fileModDate = modDate(url)
        case .file:
            if doc.isDirty { try pending.save(doc.text, for: doc.id) }
        }
        doc.needsFlush = false
    }

    /// Bir sekme yazılamasa da diğerlerini ve oturumu yazar; sonra ilk hatayı fırlatır.
    public func flushAll() throws {
        var firstError: Error?
        for doc in tabs {
            do { try flush(doc.id) } catch { firstError = firstError ?? error }
        }
        try persistSession()
        if let firstError { throw firstError }
    }

    public func closeAction(for id: UUID) -> CloseAction {
        guard let doc = tab(id) else { return .closeSilently }
        return NotepadCore.closeAction(kind: doc.kind, text: doc.text, isDirty: doc.isDirty)
    }

    /// Boş temp not kalıcı silinir; dolu temp not `discard` ise Çöp Sepeti'ne gider. Son sekme kapanırsa yeni boş sekme açılır.
    public func close(_ id: UUID, discard: Bool) throws {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let doc = tabs[index]
        switch doc.kind {
        case .temp(let url):
            if doc.text.isBlank {
                try? temps.deletePermanently(url)
            } else if discard {
                try temps.moveToTrash(url)
            } else {
                try flush(id)
            }
        case .file:
            if discard { pending.remove(id) } else { try flush(id) }
        }
        tabs.remove(at: index)
        if tabs.isEmpty {
            try newTab()
            return
        }
        if activeID == id {
            activeID = tabs[min(index, tabs.count - 1)].id
        }
        try persistSession()
        onChange?()
    }

    public func persistSession() throws {
        try sessionStore.save(Session(tabs: tabs.map { TabRecord(id: $0.id, kind: $0.kind) }, activeTabID: activeID))
    }

    /// Sekmeyi ekler ve açık sekmelerde kullanılmayan en küçük "Untitled" numarasını verir.
    private func add(_ doc: TabDocument) {
        let used = Set(tabs.map(\.untitledNumber))
        doc.untitledNumber = (1...).first { !used.contains($0) }!
        tabs.append(doc)
    }

    func modDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}

// MARK: - Dosya işlemleri

extension Workspace {
    /// Dosyayı yeni sekmede açar; zaten açıksa o sekmeyi seçer. UTF-8 değilse `TextFileError.notUTF8`.
    @discardableResult
    public func open(_ url: URL) throws -> TabDocument {
        if let existing = tabs.first(where: { $0.kind.url.canonical == url.canonical }) {
            select(existing.id)
            return existing
        }
        let doc = TabDocument(kind: .file(url), text: try TextFile.read(url), fileModDate: modDate(url))
        add(doc)
        activeID = doc.id
        try persistSession()
        onChange?()
        return doc
    }

    /// Temp notta ya da dosyası artık diskte olmayan sekmede konum sorulmalı.
    public func needsSavePanel(_ id: UUID) -> Bool {
        guard let doc = tab(id) else { return false }
        switch doc.kind {
        case .temp: return true
        case .file(let url): return !FileManager.default.fileExists(atPath: url.path)
        }
    }

    public func save(_ id: UUID) throws {
        guard let doc = tab(id), case .file(let url) = doc.kind else { return }
        try TextFile.write(doc.text, to: url)
        markSaved(doc, at: url)
        onChange?()
    }

    /// Sekmeyi `url`'ye bağlar. Temp notun eski dosyası Çöp Sepeti'ne gider; aynı dosya başka sekmede açıksa o sekme kapanır.
    public func saveAs(_ id: UUID, to url: URL) throws {
        guard let doc = tab(id) else { return }
        try TextFile.write(doc.text, to: url)
        let old = doc.kind
        for other in tabs where other.id != id && other.kind.url.canonical == url.canonical {
            pending.remove(other.id)
        }
        tabs.removeAll { $0.id != id && $0.kind.url.canonical == url.canonical }
        doc.kind = .file(url)
        markSaved(doc, at: url)
        try persistSession()
        if case .temp(let tempURL) = old, tempURL.canonical != url.canonical {
            // Metin zaten yeni dosyada; temp silinemezse sonraki açılışta sahipsiz not olarak görünür, kayıp olmaz.
            try? temps.moveToTrash(tempURL)
        }
        onChange?()
    }

    /// Bizde değişmemiş sekmeleri (temp ya da dosya), dosyası dışarıdan değiştiyse yeniden okur.
    public func reloadChangedFiles() {
        var changed = false
        for doc in tabs {
            let untouched = doc.kind.isTemp ? !doc.needsFlush : !doc.isDirty
            let url = doc.kind.url
            guard untouched, let date = modDate(url), date != doc.fileModDate,
                  let text = try? TextFile.read(url) else { continue }
            doc.text = text
            doc.fileModDate = date
            changed = true
        }
        if changed { onChange?() }
    }

    private func markSaved(_ doc: TabDocument, at url: URL) {
        doc.isDirty = false
        doc.needsFlush = false
        doc.fileModDate = modDate(url)
        pending.remove(doc.id)
    }
}
