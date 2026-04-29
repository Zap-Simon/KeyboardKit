import SwiftUI

// MARK: - ClipboardPanelView
// Full-keyboard-height panel shown instead of the normal keyboard content
// when the user taps the history button. Follows the same ZStack-swap
// pattern used by SettingsPanelView.

struct ClipboardPanelView: View {
    @ObservedObject var store: ClipboardHistoryStore
    let onInsert: (String) -> Void
    let onClose: () -> Void

    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            if store.entries.isEmpty {
                emptyState
            } else {
                entriesList
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .confirmationDialog("Clear all history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear All", role: .destructive) { store.clear() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.accentColor)
            Text("History")
                .font(.system(size: 14, weight: .bold))
            Spacer()
            if !store.entries.isEmpty {
                Button {
                    showClearConfirm = true
                } label: {
                    Text("Clear")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(KeyboardCardBackground(cornerRadius: 8))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
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
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundColor(.secondary)
            Text("No history yet")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 24)
    }

    // MARK: Entries list

    private var entriesList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 5) {
                ForEach(store.entries) { entry in
                    ClipboardEntryRow(
                        entry: entry,
                        onInsert: {
                            onInsert(entry.text)
                            onClose()
                        },
                        onDelete: {
                            if let idx = store.entries.firstIndex(where: { $0.id == entry.id }) {
                                store.delete(at: IndexSet([idx]))
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - ClipboardEntryRow

private struct ClipboardEntryRow: View {
    let entry: ClipboardEntry
    let onInsert: () -> Void
    let onDelete: () -> Void

    @State private var showDelete = false

    var body: some View {
        HStack(spacing: 8) {
            // Mode badge
            Text(entry.modeLabel)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.accentColor.opacity(0.8)))
                .fixedSize()

            // Content preview
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.text.components(separatedBy: "\n").first ?? entry.text)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(entry.date, style: .relative)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Insert button
            Button(action: onInsert) {
                Image(systemName: "arrow.up.doc")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accentColor)
                    .frame(width: 28, height: 28)
                    .background(KeyboardCardBackground(cornerRadius: 7))
                    .cornerRadius(7)
            }
            .buttonStyle(.plain)

            // Delete button (shown via swipe or long-press)
            if showDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(width: 28, height: 28)
                        .background(KeyboardCardBackground(cornerRadius: 7))
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(KeyboardCardBackground(cornerRadius: 9))
        .cornerRadius(9)
        .onLongPressGesture {
            withAnimation(.spring(response: 0.2)) { showDelete.toggle() }
        }
    }
}
