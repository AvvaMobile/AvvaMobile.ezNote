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
                add(TabDocument(id: record.id, kind: record.kind, text: text))
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
            add(TabDocument(kind: .temp(url), text: text))
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
        let doc = TabDocument(kind: .temp(try temps.create(now: now())), text: "")
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
        if !doc.kind.isTemp { doc.isDirty = true }
        onChange?()
    }

    /// Temp notu dosyasına, değişmiş dosya sekmesini bekleyen değişikliklere yazar.
    public func flush(_ id: UUID) throws {
        guard let doc = tab(id) else { return }
        switch doc.kind {
        case .temp(let url): try TextFile.write(doc.text, to: url)
        case .file: if doc.isDirty { try pending.save(doc.text, for: doc.id) }
        }
    }

    public func flushAll() throws {
        for doc in tabs { try flush(doc.id) }
        try persistSession()
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

    /// Sekmeyi ekler ve açık sekmelerde kullanılmayan en küçük "Adsız" numarasını verir.
    private func add(_ doc: TabDocument) {
        let used = Set(tabs.map(\.untitledNumber))
        doc.untitledNumber = (1...).first { !used.contains($0) }!
        tabs.append(doc)
    }

    func modDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
