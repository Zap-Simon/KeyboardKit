import SwiftUI

struct SettingsPanelView: View {
    @ObservedObject var presetsStore: PresetsStore
    @ObservedObject var state: KeyboardState

    @State private var editingPreset: GlassPreset?
    @State private var isCreatingPreset = false
    @AppStorage(KeyboardPreferences.debugModeKey, store: UserDefaults.standard) private var isDebugModeEnabled = false

    var body: some View {
        Group {
            if let editingPreset {
                PresetEditorView(
                    presetsStore: presetsStore,
                    preset: editingPreset,
                    isNew: isCreatingPreset,
                    onDismiss: closeEditor
                )
            } else {
                presetList
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var presetList: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("Glass Presets")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                SettingsIconButton(systemName: "plus", title: "New") {
                    isCreatingPreset = true
                    editingPreset = GlassPreset(name: "", adjustment: 10)
                }

                Button(action: { state.showSettings = false }) {
                    Text("Done")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 7) {
                    ForEach(Array(presetsStore.presets.enumerated()), id: \.element.id) { index, preset in
                        PresetRowView(
                            preset: preset,
                            isFavorite: presetsStore.isFavorite(preset),
                            canMoveUp: index > 0,
                            canMoveDown: index < presetsStore.presets.count - 1,
                            onEdit: {
                                isCreatingPreset = false
                                editingPreset = preset
                            },
                            onFavorite: { presetsStore.toggleFavorite(preset) },
                            onDelete: { deletePreset(preset) },
                            onMoveUp: { movePreset(from: index, to: index - 1) },
                            onMoveDown: { movePreset(from: index, to: index + 1) }
                        )
                    }
                }
                .padding(.bottom, 4)
            }

            debugModeRow
        }
    }

    private var debugModeRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Debug Mode")
                    .font(.system(size: 13, weight: .semibold))
                Text("Show or hide the diagnostics overlay while testing the keyboard.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Toggle("Debug Mode", isOn: $isDebugModeEnabled)
                .labelsHidden()
                .tint(.accentColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.58))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    private func closeEditor() {
        editingPreset = nil
        isCreatingPreset = false
    }

    private func deletePreset(_ preset: GlassPreset) {
        guard let index = presetsStore.presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presetsStore.delete(at: IndexSet(integer: index))
    }

    private func movePreset(from source: Int, to destination: Int) {
        guard presetsStore.presets.indices.contains(source), presetsStore.presets.indices.contains(destination) else { return }
        let moveDestination = destination > source ? destination + 1 : destination
        presetsStore.move(from: IndexSet(integer: source), to: moveDestination)
    }
}

private struct SettingsIconButton: View {
    let systemName: String
    let title: String
    var foregroundColor: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.58))
                .foregroundColor(foregroundColor)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct PresetRowView: View {
    let preset: GlassPreset
    let isFavorite: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onEdit: () -> Void
    let onFavorite: () -> Void
    let onDelete: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(preset.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text("\(preset.adjustment > 0 ? "Sight" : "Tight") \(preset.adjustmentLabel)mm = Glazing")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Text("\(preset.adjustmentLabel)mm")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.accentColor)
                .frame(minWidth: 42, alignment: .trailing)

            VStack(spacing: 4) {
                Button(action: onMoveUp) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 28, height: 18)
                        .background(Color.white.opacity(canMoveUp ? 0.50 : 0.22))
                        .foregroundColor(canMoveUp ? .primary : Color(UIColor.tertiaryLabel))
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .disabled(!canMoveUp)

                Button(action: onMoveDown) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 28, height: 18)
                        .background(Color.white.opacity(canMoveDown ? 0.50 : 0.22))
                        .foregroundColor(canMoveDown ? .primary : Color(UIColor.tertiaryLabel))
                        .cornerRadius(7)
                }
                .buttonStyle(.plain)
                .disabled(!canMoveDown)
            }

            SettingsIconButton(systemName: isFavorite ? "star.fill" : "star", title: "Favorite", foregroundColor: isFavorite ? .yellow : .primary, action: onFavorite)
            SettingsIconButton(systemName: "pencil", title: "Edit", action: onEdit)
            SettingsIconButton(systemName: "trash", title: "Delete", foregroundColor: .red, action: onDelete)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.58))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
        .cornerRadius(10)
    }
}

struct PresetEditorView: View {
    @ObservedObject var presetsStore: PresetsStore

    var isNew: Bool
    let onDismiss: () -> Void

    @State private var name: String
    @State private var adjustment: Int
    @State private var originalPreset: GlassPreset

    init(presetsStore: PresetsStore, preset: GlassPreset, isNew: Bool = false, onDismiss: @escaping () -> Void) {
        self.presetsStore = presetsStore
        self.isNew = isNew
        self.onDismiss = onDismiss
        _name = State(initialValue: preset.name)
        _adjustment = State(initialValue: preset.adjustment)
        _originalPreset = State(initialValue: preset)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var exampleBaseName: String { adjustment > 0 ? "Sight" : "Tight" }
    private var exampleBase: Int { 1200 }
    private var exampleCut: Int { exampleBase + adjustment }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                SettingsIconButton(systemName: "chevron.left", title: "Back", action: onDismiss)

                Text(isNew ? "New Preset" : "Edit Preset")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                Button(action: savePreset) {
                    Text("Save")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(canSave ? Color.accentColor : Color.white.opacity(0.36))
                        .foregroundColor(canSave ? .white : Color(UIColor.tertiaryLabel))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    EditorSection(title: "Preset Name") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(name.isEmpty ? "Type preset name below" : name)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(name.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                                .padding(.horizontal, 10)
                                .background(Color.white.opacity(0.52))
                                .cornerRadius(9)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9)
                                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                                )

                            PresetNamePadView(
                                onCharacter: { name.append($0) },
                                onSpace: { name.append(" ") },
                                onBackspace: {
                                    guard !name.isEmpty else { return }
                                    name.removeLast()
                                },
                                onClear: { name = "" }
                            )
                        }
                    }

                    EditorSection(title: "Adjustment") {
                        HStack(spacing: 8) {
                            AdjustmentButton(systemName: "minus", isEnabled: adjustment > -100) {
                                adjustment -= 1
                            }

                            VStack(spacing: 2) {
                                Text(adjustment > 0 ? "+\(adjustment)mm" : "\(adjustment)mm")
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.accentColor)

                                Text("\(exampleBaseName) \(exampleBase) \(adjustment > 0 ? "+" : "-") \(abs(adjustment)) = Glazing \(exampleCut)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white.opacity(0.52))
                            .cornerRadius(9)

                            AdjustmentButton(systemName: "plus", isEnabled: adjustment < 100) {
                                adjustment += 1
                            }
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func savePreset() {
        guard canSave else { return }
        let updated = GlassPreset(id: originalPreset.id, name: name.trimmingCharacters(in: .whitespaces), adjustment: adjustment)
        if isNew {
            presetsStore.add(updated)
        } else {
            presetsStore.update(updated)
        }
        onDismiss()
    }
}

private struct EditorSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            content()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.58))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
        .cornerRadius(10)
    }
}

private struct AdjustmentButton: View {
    let systemName: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .frame(width: 44, height: 52)
                .background(isEnabled ? Color.white.opacity(0.58) : Color.white.opacity(0.22))
                .foregroundColor(isEnabled ? .primary : Color(UIColor.tertiaryLabel))
                .cornerRadius(9)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct PresetNamePadView: View {
    let onCharacter: (String) -> Void
    let onSpace: () -> Void
    let onBackspace: () -> Void
    let onClear: () -> Void

    private let rows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"],
        ["K", "L", "M", "N", "O", "P", "Q", "R", "S", "T"],
        ["U", "V", "W", "X", "Y", "Z", ".", "-", "/"]
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { rowIndex in
                HStack(spacing: 6) {
                    ForEach(rows[rowIndex], id: \.self) { key in
                        Button(action: { onCharacter(key) }) {
                            Text(key)
                                .font(.system(size: 14, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(Color.white.opacity(0.58))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.white.opacity(0.24), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 6) {
                Button(action: onClear) {
                    Text("Clear")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 70, height: 36)
                        .background(Color.white.opacity(0.46))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onSpace) {
                    Text("Space")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(Color.white.opacity(0.58))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.24), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onBackspace) {
                    Image(systemName: "delete.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 70, height: 36)
                        .background(Color.white.opacity(0.46))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}