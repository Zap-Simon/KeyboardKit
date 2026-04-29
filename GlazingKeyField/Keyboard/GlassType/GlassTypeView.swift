import SwiftUI
import KeyboardKit

// MARK: - GlassTypeTabView
// The "Type" tab — glass build selector with predictive text chip strip.

struct GlassTypeTabView: View {
    @ObservedObject var glassState: GlassTypeState
    let onBuildConfirmed: (GlassBuild) -> Void   // called when user confirms via ✓

    var body: some View {
        VStack(spacing: 4) {
            buildModeSelector
            buildDisplay
            suggestionsStrip
        }
    }

    // MARK: Build Mode

    private var buildModeSelector: some View {
        HStack(spacing: 0) {
            ForEach(["Single", "DGU"], id: \.self) { label in
                let isDGU  = label == "DGU"
                let active = isDGU == (glassState.buildMode == .dgu)
                Button {
                    withAnimation(.spring(response: 0.22, dampingFraction: 0.85)) {
                        glassState.setBuildMode(isDGU ? .dgu : .single)
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .foregroundColor(active ? .primary : .secondary)
                .buttonStyle(.plain)
            }
        }
        .frame(height: 28)
        .background {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                GeometryReader { proxy in
                    let w = proxy.size.width / 2
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(UIColor.systemBackground))
                        .shadow(color: .black.opacity(0.12), radius: 2, x: 0, y: 1)
                        .padding(2)
                        .frame(width: w)
                        .offset(x: glassState.buildMode == .dgu ? w : 0)
                        .animation(.spring(response: 0.22, dampingFraction: 0.85), value: glassState.buildMode)
                }
            }
        }
        .padding(.horizontal, 14)
    }

    // MARK: Build Display

    @ViewBuilder
    private var buildDisplay: some View {
        if glassState.buildMode == .single {
            singlePane
        } else {
            dguPane
        }
    }

    private var singlePane: some View {
        HStack(spacing: 8) {
            glassSlot(
                label: "Glass Type",
                value: glassState.outerPane?.name,
                placeholder: "Search…",
                isActive: glassState.outerPane == nil
            ) {
                glassState.outerPane = nil
                glassState.clearSearch()
            }
        }
        .padding(.horizontal, 14)
    }

    private var dguPane: some View {
        HStack(spacing: 6) {
            glassSlot(
                label: "Outer",
                value: glassState.outerPane?.name,
                placeholder: "Search…",
                isActive: glassState.outerPane == nil
            ) {
                glassState.outerPane = nil
                glassState.clearSearch()
            }

            // Spacer bar chip
            VStack(spacing: 2) {
                Text("Spacer")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach([6, 8, 10, 12, 14, 16] as [Int], id: \.self) { mm in
                            let sel = glassState.spacerBar?.thicknessMm == mm
                            Button {
                                glassState.spacerBar = GlassTypeCatalogue.spacerBars.first {
                                    $0.thicknessMm == mm &&
                                    ($0.colour == (glassState.spacerBar?.colour ?? .black))
                                } ?? GlassTypeCatalogue.spacerBars.first { $0.thicknessMm == mm }
                            } label: {
                                Text("\(mm)mm")
                                    .font(.system(size: 10, weight: .bold))
                                    .padding(.horizontal, 6)
                                    .frame(height: 22)
                                    .background(sel ? Color.accentColor : KeyboardCardBackground(cornerRadius: 6))
                                    .foregroundColor(sel ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                // Colour chips
                HStack(spacing: 4) {
                    ForEach(SpacerColour.allCases) { col in
                        let sel = glassState.spacerBar?.colour == col
                        Button {
                            let mm = glassState.spacerBar?.thicknessMm ?? 10
                            glassState.spacerBar = GlassTypeCatalogue.spacerBars.first {
                                $0.thicknessMm == mm && $0.colour == col
                            } ?? GlassTypeCatalogue.spacerBars.first { $0.colour == col }
                        } label: {
                            Text(col.displayTitle)
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 5)
                                .frame(height: 18)
                                .background(sel ? Color.accentColor : KeyboardCardBackground(cornerRadius: 5))
                                .foregroundColor(sel ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minWidth: 80)

            glassSlot(
                label: "Inner",
                value: glassState.innerPane?.name ?? glassState.outerPane.map { "Same: \($0.name)" },
                placeholder: "Same as outer",
                isActive: glassState.outerPane != nil && glassState.innerPane == nil
            ) {
                glassState.innerPane = nil
                glassState.clearSearch()
            }
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func glassSlot(
        label: String,
        value: String?,
        placeholder: String,
        isActive: Bool,
        onClear: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary)

            ZStack(alignment: .trailing) {
                Text(value ?? placeholder)
                    .font(.system(size: value == nil ? 11 : 10, weight: value == nil ? .medium : .semibold))
                    .foregroundColor(value == nil ? .secondary : .primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 6)
                    .padding(.trailing, value != nil ? 22 : 6)

                if value != nil {
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 4)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 32)
            .background {
                KeyboardCardBackground(cornerRadius: 7)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(
                        isActive ? Color.accentColor.opacity(0.85) : Color.secondary.opacity(0.18),
                        lineWidth: 1.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Suggestions strip

    @ViewBuilder
    private var suggestionsStrip: some View {
        let chips = glassState.suggestions.prefix(4)
        if !chips.isEmpty || !glassState.searchQuery.isEmpty {
            VStack(spacing: 2) {
                if !glassState.searchQuery.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(glassState.searchQuery)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            glassState.clearSearch()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 14)
                }

                if !chips.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(chips) { type in
                                Button {
                                    glassState.selectSuggestion(type)
                                } label: {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(type.name)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(type.category.rawValue)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(KeyboardCardBackground(cornerRadius: 8))
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 2)
                    }
                } else if !glassState.searchQuery.isEmpty {
                    Text("No results")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

// MARK: - GlassTypeSummaryView
// Shown in the Weight tab header to display the confirmed build details.

struct GlassTypeSummaryBadge: View {
    let build: GlassBuild

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: build.isDGU ? "square.stack" : "square")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.accentColor)
            Text(build.displayName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(KeyboardCardBackground(cornerRadius: 12))
        .clipShape(Capsule())
    }
}
