import Foundation

// MARK: - ClipboardEntry

struct ClipboardEntry: Identifiable, Codable {
    let id: UUID
    let text: String
    let date: Date
    let modeLabel: String   // e.g. "Size", "Weight", "Type"
}

// MARK: - ClipboardHistoryStore

final class ClipboardHistoryStore: ObservableObject {

    private let storageKey = "glazing_clipboard_v1"
    private let maxCount = 50

    @Published private(set) var entries: [ClipboardEntry] = []

    init() { load() }

    // MARK: Mutations

    func add(_ text: String, modeLabel: String) {
        // Skip exact duplicate of most-recent entry
        guard entries.first?.text != text else { return }
        let entry = ClipboardEntry(id: UUID(), text: text, date: Date(), modeLabel: modeLabel)
        entries.insert(entry, at: 0)
        if entries.count > maxCount {
            entries = Array(entries.prefix(maxCount))
        }
        save()
    }

    func delete(at offsets: IndexSet) {
        entries.remove(atOffsets: offsets)
        save()
    }

    func clear() {
        entries = []
        save()
    }

    // MARK: Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([ClipboardEntry].self, from: data)
        else { return }
        entries = decoded
    }
}
