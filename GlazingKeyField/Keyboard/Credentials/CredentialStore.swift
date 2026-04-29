import Foundation
import Security

// MARK: - Credential

struct Credential: Identifiable, Codable {
    var id: UUID
    var label: String       // e.g. "Site A – Admin", "Client Portal"
    var username: String
    var password: String    // stored encrypted in Keychain

    init(id: UUID = UUID(), label: String, username: String, password: String) {
        self.id = id
        self.label = label
        self.username = username
        self.password = password
    }
}

// MARK: - CredentialStore
//
// Stores the full credential list as a single JSON blob in the Keychain so
// passwords are never written to UserDefaults or any plaintext store.
// Requires Full Access on the keyboard extension (already needed for clipboard).

final class CredentialStore: ObservableObject {

    @Published private(set) var credentials: [Credential] = []

    private let service = "com.glazingkey.field.credentials"
    private let account = "saved_credentials"

    init() { load() }

    // MARK: - Mutations

    func add(label: String, username: String, password: String) {
        let c = Credential(label: label, username: username, password: password)
        credentials.append(c)
        save()
    }

    func update(_ updated: Credential) {
        guard let idx = credentials.firstIndex(where: { $0.id == updated.id }) else { return }
        credentials[idx] = updated
        save()
    }

    func delete(at offsets: IndexSet) {
        credentials.remove(atOffsets: offsets)
        save()
    }

    func delete(id: UUID) {
        credentials.removeAll { $0.id == id }
        save()
    }

    // MARK: - Keychain persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(credentials) else { return }
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     account
        ]
        let attributes: [CFString: Any] = [
            kSecValueData:       data,
            kSecAttrAccessible:  kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        // Try update first; if nothing exists, add a new item.
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private func load() {
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     account,
            kSecReturnData:      true,
            kSecMatchLimit:      kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let decoded = try? JSONDecoder().decode([Credential].self, from: data)
        else { return }
        credentials = decoded
    }
}
