import SwiftUI

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

    var body: some View {
        VStack(spacing: 0) {
            header
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
                        onInsertPassword: {
                            onInsert(credential.password)
                            onClose()
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
    let onInsertPassword: () -> Void
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
                Button(action: onInsertPassword) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .frame(width: 28, height: 24)
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
    @FocusState private var focused: Field?

    private enum Field { case label, username, password }

    var canSave: Bool { !username.isEmpty && !password.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("New Login")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.accentColor)

            formField(placeholder: "Label (e.g. Site A Admin)", text: $label, field: .label, secure: false)
            formField(placeholder: "Username / email", text: $username, field: .username, secure: false)
            formField(placeholder: "Password", text: $password, field: .password, secure: true)

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .buttonStyle(.plain)
                Button("Save") {
                    onSave(label, username, password)
                }
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

    private func formField(placeholder: String, text: Binding<String>, field: Field, secure: Bool) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: text)
                    .focused($focused, equals: field)
            } else {
                TextField(placeholder, text: text)
                    .focused($focused, equals: field)
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(.systemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
    }
}
