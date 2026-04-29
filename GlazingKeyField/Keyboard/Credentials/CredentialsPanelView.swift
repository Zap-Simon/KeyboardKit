import SwiftUI
import UIKit

// MARK: - CredentialsPanelView
// Full-keyboard-height panel for saving and inserting login credentials.
// Passwords are stored in the iOS Keychain (never UserDefaults/plaintext).
// Shown via the same ZStack-swap pattern used by ClipboardPanelView.

struct CredentialsPanelView: View {
    @ObservedObject var store: CredentialStore
    /// Called with the text to type into the host app's focused field.
    let onInsert: (String) -> Void
    let onClose: () -> Void

    @State private var showAddForm = false
    @State private var deleteTarget: UUID?
    @State private var showCopiedBanner = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if showCopiedBanner {
                copiedBanner
            }
            Divider().opacity(0.3)
            if store.credentials.isEmpty && !showAddForm {
                emptyState
            } else {
                credentialsList
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .confirmationDialog("Delete this credential?", isPresented: .constant(deleteTarget != nil), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let id = deleteTarget { store.delete(id: id) }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.accentColor)
            Text("Saved Logins")
                .font(.system(size: 14, weight: .bold))
            Spacer()
            Button {
                withAnimation(.spring(response: 0.25)) { showAddForm.toggle() }
            } label: {
                Image(systemName: showAddForm ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 20))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 8)
    }

    // MARK: Copied banner

    private var copiedBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.green)
            Text("Password copied — tap & hold the password field to paste")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.green.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.3), lineWidth: 1))
        )
        .padding(.horizontal, 10)
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "key")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("No saved logins")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Text("Tap + to add a username & password")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 16)
    }

    // MARK: Credentials list

    private var credentialsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 5) {
                if showAddForm {
                    AddCredentialRow(onSave: { label, user, pass in
                        store.add(label: label, username: user, password: pass)
                        withAnimation(.spring(response: 0.25)) { showAddForm = false }
                    }, onCancel: {
                        withAnimation(.spring(response: 0.25)) { showAddForm = false }
                    })
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                ForEach(store.credentials) { credential in
                    CredentialRow(
                        credential: credential,
                        onInsertUsername: {
                            onInsert(credential.username)
                            onClose()
                        },
                        onCopyPassword: {
                            UIPasteboard.general.string = credential.password
                            withAnimation(.spring(response: 0.25)) {
                                showCopiedBanner = true
                            }
                            // Auto-dismiss banner after 3s
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation { showCopiedBanner = false }
                            }
                        },
                        onDelete: { deleteTarget = credential.id }
                    )
                }
            }
        }
    }
}

// MARK: - CredentialRow

private struct CredentialRow: View {
    let credential: Credential
    let onInsertUsername: () -> Void
    let onCopyPassword: () -> Void
    let onDelete: () -> Void

    @State private var showDelete = false
    @State private var showPassword = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Label row
            HStack(spacing: 6) {
                Text(credential.label.isEmpty ? "Login" : credential.label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Spacer()
                if showDelete {
                    Button(action: onDelete) {
                        Label("Delete", systemImage: "trash")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.red)
                            .labelStyle(.iconOnly)
                            .frame(width: 24, height: 24)
                            .background(KeyboardCardBackground(cornerRadius: 6))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }

            // Username row
            HStack(spacing: 6) {
                Image(systemName: "person.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 14)
                Text(credential.username)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                Button(action: onInsertUsername) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .frame(width: 28, height: 24)
                        .background(KeyboardCardBackground(cornerRadius: 6))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            // Password row
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 14)
                Text(showPassword ? credential.password : String(repeating: "•", count: min(credential.password.count, 12)))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(showPassword ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) { showPassword.toggle() }
                    }
                Text(showPassword ? "hide" : "show")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) { showPassword.toggle() }
                    }
                Spacer()
                Button(action: onCopyPassword) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.clipboard")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Copy")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.accentColor)
                    .frame(height: 24)
                    .padding(.horizontal, 7)
                    .background(KeyboardCardBackground(cornerRadius: 6))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(KeyboardCardBackground(cornerRadius: 9))
        .cornerRadius(9)
        .onLongPressGesture {
            withAnimation(.spring(response: 0.2)) { showDelete.toggle() }
        }
    }
}

// MARK: - AddCredentialRow

private struct AddCredentialRow: View {
    let onSave: (String, String, String) -> Void
    let onCancel: () -> Void

    @State private var label = ""
    @State private var username = ""
    @State private var password = ""
    @State private var activeField: Field = .username
    @State private var showPassword = false

    private enum Field {
        case label, username, password
        var icon: String {
            switch self {
            case .label:    return "tag"
            case .username: return "person.fill"
            case .password: return "lock.fill"
            }
        }
        var placeholder: String {
            switch self {
            case .label:    return "Label (e.g. Site A)"
            case .username: return "Username / email"
            case .password: return "Password"
            }
        }
    }

    var canSave: Bool { !username.isEmpty && !password.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("New Login")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.accentColor)

            fieldDisplay(.label,    value: label)
            fieldDisplay(.username, value: username)
            fieldDisplay(.password, value: password)

            CredentialKeypad(
                onCharacter: { appendToActive($0) },
                onBackspace:  { deleteFromActive() },
                onSpace:      { appendToActive(" ") },
                onNextField:  { advanceField() }
            )

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .buttonStyle(.plain)
                Button("Save") { onSave(label, username, password) }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(canSave ? .white : .secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(canSave ? Color.accentColor : Color.secondary.opacity(0.2))
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                    .disabled(!canSave)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(KeyboardCardBackground(cornerRadius: 9))
        .cornerRadius(9)
    }

    @ViewBuilder
    private func fieldDisplay(_ field: Field, value: String) -> some View {
        let isActive = activeField == field
        let isMasked = field == .password && !showPassword && !value.isEmpty
        let display = value.isEmpty
            ? field.placeholder
            : (isMasked ? String(repeating: "•", count: value.count) : value)

        Button(action: { activeField = field }) {
            HStack(spacing: 6) {
                Image(systemName: field.icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(isActive ? .accentColor : .secondary)
                    .frame(width: 14)
                Text(display + (isActive ? "▌" : ""))
                    .font(.system(size: 12,
                                  weight: value.isEmpty ? .regular : .medium,
                                  design: .monospaced))
                    .foregroundColor(value.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if field == .password && !value.isEmpty {
                    Button { showPassword.toggle() } label: {
                        Text(showPassword ? "hide" : "show")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(UIColor.secondarySystemBackground).opacity(0.6))
                    .overlay(RoundedRectangle(cornerRadius: 6)
                        .stroke(isActive ? Color.accentColor.opacity(0.7) : Color.clear,
                                lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func appendToActive(_ char: String) {
        switch activeField {
        case .label:    label.append(contentsOf: char)
        case .username: username.append(contentsOf: char)
        case .password: password.append(contentsOf: char)
        }
    }

    private func deleteFromActive() {
        switch activeField {
        case .label:    if !label.isEmpty    { label.removeLast() }
        case .username: if !username.isEmpty { username.removeLast() }
        case .password: if !password.isEmpty { password.removeLast() }
        }
    }

    private func advanceField() {
        switch activeField {
        case .label:    activeField = .username
        case .username: activeField = .password
        case .password: activeField = .label
        }
    }
}

// MARK: - CredentialKeypad

private struct CredentialKeypad: View {
    let onCharacter: (String) -> Void
    let onBackspace: () -> Void
    let onSpace: () -> Void
    let onNextField: () -> Void

    @State private var isUppercase = false
    @State private var showSymbols = false

    private let alphaRows: [[String]] = [
        ["q","w","e","r","t","y","u","i","o","p"],
        ["a","s","d","f","g","h","j","k","l"],
        ["z","x","c","v","b","n","m"]
    ]
    private let symbolRows: [[String]] = [
        ["@",".","-","_","+","=","~","<",">","/"],
        ["!","#","$","%","^","&","*","(",")",";"],
        ["1","2","3","4","5","6","7","8","9","0"]
    ]

    var body: some View {
        VStack(spacing: 3) {
            let activeRows = showSymbols ? symbolRows : alphaRows
            ForEach(activeRows.indices, id: \.self) { i in
                credRow(activeRows[i].map { isUppercase ? $0.uppercased() : $0 })
            }

            // Action row
            HStack(spacing: 3) {
                Button(action: { showSymbols.toggle() }) {
                    Text(showSymbols ? "ABC" : "!@#")
                        .font(.system(size: 10, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(RoundedRectangle(cornerRadius: 5)
                            .fill(Color(UIColor.tertiarySystemBackground)))
                        .foregroundColor(.primary)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)

                if !showSymbols {
                    Button(action: { isUppercase.toggle() }) {
                        Image(systemName: isUppercase ? "shift.fill" : "shift")
                            .font(.system(size: 11, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 26)
                            .background(RoundedRectangle(cornerRadius: 5)
                                .fill(Color(UIColor.tertiarySystemBackground)))
                            .foregroundColor(isUppercase ? .accentColor : .primary)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: onSpace) {
                    Text("Space")
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(RoundedRectangle(cornerRadius: 5)
                            .fill(Color(UIColor.tertiarySystemBackground)))
                        .foregroundColor(.primary)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)

                Button(action: onNextField) {
                    Image(systemName: "arrow.right.to.line")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 34, height: 26)
                        .background(RoundedRectangle(cornerRadius: 5)
                            .fill(Color(UIColor.tertiarySystemBackground)))
                        .foregroundColor(.accentColor)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)

                Button(action: onBackspace) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 34, height: 26)
                        .background(RoundedRectangle(cornerRadius: 5)
                            .fill(Color(UIColor.tertiarySystemBackground)))
                        .foregroundColor(.primary)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private func credRow(_ keys: [String]) -> some View {
        HStack(spacing: 3) {
            ForEach(keys, id: \.self) { key in
                Button(action: { onCharacter(key) }) {
                    Text(key)
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 26)
                        .background(RoundedRectangle(cornerRadius: 5)
                            .fill(Color(UIColor.secondarySystemBackground)))
                        .foregroundColor(.primary)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
