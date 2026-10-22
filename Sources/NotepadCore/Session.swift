import Foundation

/// Sekmenin bağlı olduğu dosya: notlar klasöründeki temp not ya da kullanıcının kaydettiği/açtığı dosya.
public enum TabKind: Codable, Equatable {
    case temp(URL)
    case file(URL)

    public var url: URL {
        switch self {
        case .temp(let url), .file(let url): url
        }
    }

    public var isTemp: Bool {
        if case .temp = self { true } else { false }
    }
}

public struct TabRecord: Codable, Equatable {
    public let id: UUID
    public let kind: TabKind

    public init(id: UUID, kind: TabKind) {
        self.id = id
        self.kind = kind
    }
}

/// Uygulama yeniden açılınca geri getirilecek sekmeler ve seçili sekme.
public struct Session: Codable, Equatable {
    public var tabs: [TabRecord]
    public var activeTabID: UUID?

    public init(tabs: [TabRecord], activeTabID: UUID?) {
        self.tabs = tabs
        self.activeTabID = activeTabID
    }
}
