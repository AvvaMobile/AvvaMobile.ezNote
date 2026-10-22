import Foundation

public enum CloseAction: Equatable {
    case closeSilently
    case askTemp
    case askFile
}

public extension String {
    /// Yalnız boşluk ve satır sonundan oluşuyorsa true.
    var isBlank: Bool { allSatisfy(\.isWhitespace) }
}

/// Boş temp not ve değişmemiş dosya sorusuz kapanır; dolu temp not ve değişmiş dosya için sorulur.
public func closeAction(kind: TabKind, text: String, isDirty: Bool) -> CloseAction {
    switch kind {
    case .temp: text.isBlank ? .closeSilently : .askTemp
    case .file: isDirty ? .askFile : .closeSilently
    }
}
