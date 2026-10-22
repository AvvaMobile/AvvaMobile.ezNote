import AppKit
import SwiftUI
import NotepadCore

/// Font ayarının tek kaynağı: Ayarlar penceresi ve ⌘+/⌘- bunu değiştirir, değişiklik kaydedilir ve editöre uygulanır.
final class FontModel: ObservableObject {
    @Published var settings: FontSettings {
        didSet { if settings != oldValue { onChange?(settings) } }
    }
    var onChange: ((FontSettings) -> Void)?

    init(settings: FontSettings) {
        self.settings = settings
    }
}

struct SettingsView: View {
    @ObservedObject var model: FontModel
    private let families = NSFontManager.shared.availableFontFamilies

    var body: some View {
        Form {
            Picker("Yazı tipi", selection: $model.settings.family) {
                Text("Sistem (eş aralıklı)").tag(String?.none)
                Divider()
                ForEach(families, id: \.self) { Text($0).tag(String?.some($0)) }
            }
            Stepper(value: $model.settings.size, in: FontSettings.minSize...FontSettings.maxSize, step: 1) {
                Text("Boyut: \(Int(model.settings.size))")
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
