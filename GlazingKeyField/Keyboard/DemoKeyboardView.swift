import SwiftUI
import KeyboardKit

private enum KeyboardLayoutMetrics {
    static let modeSelectorHeight: CGFloat = 28
    static let selectorHeight: CGFloat = 60
    // 148pt: cards are ~60pt layout height (cut mode). 60+6+82=148 when clearance shown.
    static let measurementHeight: CGFloat = 148
    static let sectionSpacing: CGFloat = 4
    static let shellCornerRadius: CGFloat = 18
}

enum KeyboardPreferences {
    static let debugModeKey = "glazing_keyboard_debug_mode_v1"
}

final class KeyboardRenderState: ObservableObject {
    @Published var isContentVisible = true
}

final class KeyboardDiagnostics: ObservableObject {
    @Published private(set) var entries: [String] = []
    @Published private(set) var rootSizeDescription: String = "--"

    func record(_ entry: String) {
        entries.append(entry)
        if entries.count > 6 {
            entries.removeFirst(entries.count - 6)
        }
    }

    func updateRootSize(_ size: CGSize) {
        let next = "\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
        guard next != rootSizeDescription else { return }
        rootSizeDescription = next
        record("root \(next)")
    }
}

enum MeasurementField: CaseIterable {
    case sightWidth, sightHeight, tightWidth, tightHeight
    case weightWidth, weightHeight
}

enum KeyboardMode: String, CaseIterable, Identifiable {
    case glassType
    case cutSize
    case weight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .glassType: return "Type"
        case .cutSize: return "Size"
        case .weight: return "Weight"
        }
    }
}

final class KeyboardState: ObservableObject {
    @Published var mode: KeyboardMode = .glassType
    @Published var sightWidth: String = ""
    @Published var sightHeight: String = ""
    @Published var tightWidth: String = ""
    @Published var tightHeight: String = ""
    @Published var weightWidth: String = ""
    @Published var weightHeight: String = ""
    @Published var activeField: MeasurementField = .sightHeight
    @Published var showSettings = false
    @Published var showClipboard = false
    @Published var showCredentials = false
    @Published var selectedPreset: GlassPreset?
    @Published var selectedWeightSpec: GlassWeightSpec?
    let glassTypeState = GlassTypeState()

    private var autoFilledWeightHeight = ""
    private var autoFilledWeightWidth = ""

    // Auto-advance between fields
    private var advanceWorkItem: DispatchWorkItem?
    private static let advanceDebounce: TimeInterval = 0.75

    init(initialPreset: GlassPreset? = nil, initialWeightSpec: GlassWeightSpec? = nil) {
        selectedPreset = initialPreset ?? GlassPreset.defaults.first
        selectedWeightSpec = initialWeightSpec ?? GlassWeightSpec.defaults.first
    }

    func value(for field: MeasurementField) -> String {
        switch field {
        case .sightWidth: return sightWidth
        case .sightHeight: return sightHeight
        case .tightWidth: return tightWidth
        case .tightHeight: return tightHeight
        case .weightWidth: return weightWidth
        case .weightHeight: return weightHeight
        }
    }

    func setValue(_ value: String, for field: MeasurementField) {
        switch field {
        case .sightWidth: sightWidth = value
        case .sightHeight: sightHeight = value
        case .tightWidth: tightWidth = value
        case .tightHeight: tightHeight = value
        case .weightWidth: weightWidth = value
        case .weightHeight: weightHeight = value
        }
    }

    func appendToActive(_ char: String) {
        // Measurement fields are numbers-only; silently reject anything that isn't a digit.
        guard char.allSatisfy({ $0.isNumber }) else { return }
        let newValue = value(for: activeField) + char
        setValue(newValue, for: activeField)
        scheduleAutoAdvance(for: newValue)
    }

    func deleteFromActive() {
        cancelAutoAdvance()
        var current = value(for: activeField)
        if !current.isEmpty {
            current.removeLast()
        }
        setValue(current, for: activeField)
    }

    func clearActive() {
        cancelAutoAdvance()
        setValue("", for: activeField)
    }

    /// Advance to the next field in the current mode, with haptic feedback.
    func advanceToNextField() {
        cancelAutoAdvance()
        let fields = modeFields
        guard let idx = fields.firstIndex(of: activeField),
              idx + 1 < fields.count else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            activeField = fields[idx + 1]
        }
    }

    private func scheduleAutoAdvance(for value: String) {
        cancelAutoAdvance()
        let digitCount = value.filter(\.isNumber).count
        if digitCount >= 4 {
            // Four digits entered — advance immediately (all glazing measurements ≤ 9999)
            advanceToNextField()
        } else if digitCount == 3 {
            // Three digits — wait briefly in case a 4th digit follows
            let work = DispatchWorkItem { [weak self] in
                DispatchQueue.main.async { self?.advanceToNextField() }
            }
            advanceWorkItem = work
            DispatchQueue.main.asyncAfter(
                deadline: .now() + KeyboardState.advanceDebounce,
                execute: work
            )
        }
    }

    private func cancelAutoAdvance() {
        advanceWorkItem?.cancel()
        advanceWorkItem = nil
    }

    /// Manually select a field, cancelling any pending auto-advance.
    func selectField(_ field: MeasurementField) {
        cancelAutoAdvance()
        activeField = field
    }

    var modeFields: [MeasurementField] {
        switch mode {
        case .glassType:
            return []   // Type tab uses chip selection, not numpad fields
        case .cutSize:
            let source = selectedPreset?.source ?? .sight
            return source == .sight
                ? [.sightHeight, .sightWidth, .tightHeight, .tightWidth]
                : [.tightHeight, .tightWidth, .sightHeight, .sightWidth]
        case .weight:
            return []   // Weight is auto-calculated from Type + Size — no manual fields
        }
    }

    func setMode(_ newMode: KeyboardMode) {
        mode = newMode
        if newMode == .weight {
            prepopulateWeightFromTypeIfAvailable()
            prepopulateWeightFromGlazingIfAvailable()
        }
        if !modeFields.contains(activeField), let first = modeFields.first {
            activeField = first
        }
    }

    /// If the Type tab has a confirmed glass build, create a weight spec from it.
    private func prepopulateWeightFromTypeIfAvailable() {
        guard let build = glassTypeState.confirmedBuild else { return }
        let kgPerM2 = Decimal(build.areaWeightKgPerM2)
        selectedWeightSpec = GlassWeightSpec(
            id: "_glass_type_\(build.outerPane?.id ?? "custom")",
            name: build.displayName,
            arealDensityKgPerM2: kgPerM2
        )
    }

    private func prepopulateWeightFromGlazingIfAvailable() {
        guard canAutoFillWeightFromGlazing, let result else { return }

        weightHeight = String(result.cutHeight)
        weightWidth = String(result.cutWidth)
        autoFilledWeightHeight = weightHeight
        autoFilledWeightWidth = weightWidth
    }

    private var canAutoFillWeightFromGlazing: Bool {
        (weightHeight.isEmpty && weightWidth.isEmpty) ||
        (weightHeight == autoFilledWeightHeight && weightWidth == autoFilledWeightWidth)
    }

    func reset() {
        cancelAutoAdvance()
        switch mode {
        case .glassType:
            glassTypeState.reset()
        case .cutSize:
            sightWidth = ""
            sightHeight = ""
            tightWidth = ""
            tightHeight = ""
            activeField = (selectedPreset?.source ?? .sight) == .sight ? .sightHeight : .tightHeight
        case .weight:
            weightWidth = ""
            weightHeight = ""
            activeField = .weightHeight
        }
    }

    var result: GlazingResult? {
        GlazingCalculator.calculate(
            sightWidthExpr: sightWidth,
            sightHeightExpr: sightHeight,
            tightWidthExpr: tightWidth,
            tightHeightExpr: tightHeight,
            preset: selectedPreset ?? GlassPreset.defaults[0]
        )
    }

    var weightResult: GlassWeightResult? {
        GlassWeightCalculator.calculate(
            widthExpr: weightWidth,
            heightExpr: weightHeight,
            spec: selectedWeightSpec ?? GlassWeightSpec.defaults[0]
        )
    }

    /// Auto-calculates weight directly from the confirmed glass type + glazing cut size.
    /// This is what the Weight tab now displays.
    var autoWeightResult: GlassWeightResult? {
        guard let build = glassTypeState.confirmedBuild,
              let sizing = result else { return nil }
        let spec = GlassWeightSpec(
            id: "_auto",
            name: build.displayName,
            arealDensityKgPerM2: Decimal(build.areaWeightKgPerM2)
        )
        return GlassWeightCalculator.calculate(widthMm: sizing.cutWidth, heightMm: sizing.cutHeight, spec: spec)
    }
}

struct KeyboardRootView: View {
    @ObservedObject var presetsStore: PresetsStore
    @ObservedObject var diagnostics: KeyboardDiagnostics
    @ObservedObject var renderState: KeyboardRenderState
    let keyboardHeight: CGFloat
    let onInsert: (String) -> Void
    let onSwitchKeyboard: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void

    @StateObject private var state = KeyboardState()
    @StateObject private var clipboardStore = ClipboardHistoryStore()
    @StateObject private var credentialStore = CredentialStore()

    init(
        presetsStore: PresetsStore,
        diagnostics: KeyboardDiagnostics,
        renderState: KeyboardRenderState,
        keyboardHeight: CGFloat,
        onInsert: @escaping (String) -> Void,
        onSwitchKeyboard: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.presetsStore = presetsStore
        self.diagnostics = diagnostics
        self.renderState = renderState
        self.keyboardHeight = keyboardHeight
        self.onInsert = onInsert
        self.onSwitchKeyboard = onSwitchKeyboard
        self.onDelete = onDelete
        self.onDismiss = onDismiss
        _state = StateObject(
            wrappedValue: KeyboardState(
                initialPreset: presetsStore.presets.first,
                initialWeightSpec: GlassWeightSpec.defaults.first
            )
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            keyboardShell
                .frame(height: keyboardHeight)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(KeyboardRootSizeReporter(diagnostics: diagnostics))
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var keyboardShell: some View {
        ZStack(alignment: .top) {
            KeyboardNeutralShellView()

            if renderState.isContentVisible {
                if state.showSettings {
                    SettingsPanelView(presetsStore: presetsStore, state: state)
                        .frame(maxWidth: .infinity, alignment: .top)
                } else if state.showClipboard {
                    ClipboardPanelView(
                        store: clipboardStore,
                        onInsert: { text in
                            onInsert(text)
                        },
                        onClose: { state.showClipboard = false }
                    )
                    .frame(maxWidth: .infinity, alignment: .top)
                } else if state.showCredentials {
                    CredentialsPanelView(
                        store: credentialStore,
                        onInsert: { text in onInsert(text) },
                        onClose: { state.showCredentials = false }
                    )
                    .frame(maxWidth: .infinity, alignment: .top)
                } else {
                    keyboardContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipShape(RoundedCorner(radius: KeyboardLayoutMetrics.shellCornerRadius, corners: [.topLeft, .topRight]))
    }

    private var keyboardContent: some View {
        VStack(spacing: 0) {
            // ── Mode tabs + utility icons (single row) ───────────────────────
            HStack(spacing: 6) {
                ModeSelectorView(state: state)

                // Credentials
                Button { state.showCredentials = true } label: {
                    Image(systemName: "key.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(credentialStore.credentials.isEmpty ? .secondary : .accentColor)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle().fill(credentialStore.credentials.isEmpty
                                ? Color.clear
                                : Color.accentColor.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)

                // History
                Button { state.showClipboard = true } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(clipboardStore.entries.isEmpty ? .secondary : .accentColor)
                        .frame(width: 26, height: 26)
                        .background(
                            Circle().fill(clipboardStore.entries.isEmpty
                                ? Color.clear
                                : Color.accentColor.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)

                // Dismiss
                Button(action: onDismiss) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // ── Scrollable content area (formula strip + main content) ────────
            // Wrapped in ScrollView so Size tab result rows never push the numpad
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: KeyboardLayoutMetrics.sectionSpacing) {
                    if state.mode == .cutSize {
                        GlassTypeSelectorView(presetsStore: presetsStore, state: state)
                    }

                    if state.mode == .glassType {
                        GlassTypeTabView(
                            glassState: state.glassTypeState,
                            onBuildConfirmed: { _ in
                                state.setMode(.cutSize)
                            }
                        )
                    } else {
                        MeasurementDisplayView(state: state)
                    }
                }
                .padding(.horizontal, 0)
                .padding(.bottom, 6)
            }

            // ── Numpad (always visible, pinned to bottom) ─────────────────────
            NumpadView(
                state: state,
                clipboardStore: clipboardStore,
                onInsert: onInsert,
                onSwitchKeyboard: onSwitchKeyboard,
                onSettings: { state.showSettings = true },
                onDelete: onDelete
            )
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

private struct KeyboardNeutralShellView: View {
    var body: some View {
        KeyboardMaterialShellView()
    }
}

private struct KeyboardMaterialShellView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        shellBackground
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.black.opacity(colorScheme == .dark ? 0.60 : 0.16))
                    .frame(height: 0.5)
            }
    }

    @ViewBuilder
    private var shellBackground: some View {
        if #available(iOS 26, *) {
            // iOS 26+: use material so the keyboard blends with the Liquid Glass chrome
            Rectangle().fill(.ultraThinMaterial)
        } else {
            // iOS 17-18: exact solid grey match for system keyboard
            colorScheme == .dark
                ? Color(red: 0.118, green: 0.118, blue: 0.125)
                : Color(red: 0.820, green: 0.835, blue: 0.859)
        }
    }
}

struct KeyboardPanelBackground: View {
    let cornerRadius: CGFloat
    var lightOverlayOpacity: CGFloat = 0.08
    var darkOverlayOpacity: CGFloat = 0.18

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        // iOS native special-key grey
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(colorScheme == .dark
                ? Color(red: 0.216, green: 0.216, blue: 0.235)
                : Color(red: 0.675, green: 0.698, blue: 0.741))
    }
}

/// White card surface: white in light mode, elevated dark grey in dark mode.
/// Used for all measurement cards, summary cards, selector chips, and cell fields.
struct KeyboardCardBackground: View {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(colorScheme == .dark ? Color(white: 0.20) : Color.white)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.0 : 0.10), radius: 0, x: 0, y: 1)
    }
}

private struct KeyboardKeyBackground: View {
    let cornerRadius: CGFloat
    let isSpecial: Bool
    let isAccent: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if isAccent {
                // Solid accent — no gradient on native-style keys
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.accentColor)
            } else if isSpecial {
                // Special (functional) keys — neutral grey
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark
                        ? Color(white: 0.16)
                        : Color(red: 0.675, green: 0.698, blue: 0.741))
            } else {
                // Regular (digit) keys — white light / neutral dark grey
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark
                        ? Color(white: 0.25)
                        : Color.white)
            }
        }
        // iOS key shadow: 1pt bottom drop, only in light mode
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.0 : 0.30), radius: 0, x: 0, y: 1)
    }
}



private struct KeyboardRootSizeReporter: View {
    @ObservedObject var diagnostics: KeyboardDiagnostics

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    diagnostics.updateRootSize(proxy.size)
                }
                .onChange(of: proxy.size) { _, newSize in
                    diagnostics.updateRootSize(newSize)
                }
        }
    }
}

private struct KeyboardDiagnosticsOverlayView: View {
    @ObservedObject var diagnostics: KeyboardDiagnostics

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("DBG root:\(diagnostics.rootSizeDescription)")
            ForEach(Array(diagnostics.entries.suffix(4).enumerated()), id: \.offset) { _, entry in
                Text(entry)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .font(.system(size: 8, weight: .semibold, design: .monospaced))
        .foregroundColor(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.74))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(8)
        .padding(.leading, 8)
        .padding(.top, 4)
        .allowsHitTesting(false)
    }
}

struct ModeSelectorView: View {
    @ObservedObject var state: KeyboardState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Track
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(colorScheme == .dark
                    ? Color(red: 0.118, green: 0.118, blue: 0.125)
                    : Color(red: 0.675, green: 0.698, blue: 0.741).opacity(0.55))

            // Animated pill
            GeometryReader { proxy in
                let count = CGFloat(KeyboardMode.allCases.count)
                let pillW = proxy.size.width / count
                let idx = CGFloat(KeyboardMode.allCases.firstIndex(of: state.mode) ?? 0)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(colorScheme == .dark
                        ? Color(white: 0.20)
                        : Color.white)
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0 : 0.18), radius: 2, x: 0, y: 1)
                    .padding(2)
                    .frame(width: pillW)
                    .offset(x: idx * pillW)
                    .animation(.spring(response: 0.22, dampingFraction: 0.85), value: state.mode)
            }
        }
        .frame(height: 28)
        .overlay {
            HStack(spacing: 0) {
                ForEach(KeyboardMode.allCases) { mode in
                    Button(action: { state.setMode(mode) }) {
                        Text(mode.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .foregroundColor(state.mode == mode ? .primary : .secondary)
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
        }
        .frame(height: KeyboardLayoutMetrics.modeSelectorHeight)
    }
}

struct GlassTypeSelectorView: View {
    @ObservedObject var presetsStore: PresetsStore
    @ObservedObject var state: KeyboardState

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Glass Formula")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if let preset = state.selectedPreset {
                    Text("\(preset.source.title) \(preset.adjustmentLabel)mm")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presetsStore.orderedPresets()) { preset in
                        let isSelected = state.selectedPreset?.id == preset.id
                        let isFavorite = presetsStore.isFavorite(preset)

                        Button(action: {
                            state.selectedPreset = preset
                            presetsStore.markRecent(preset)
                        }) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(preset.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .lineLimit(1)
                                    if isFavorite {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(isSelected ? .white : .yellow)
                                    }
                                }
                                Text("\(preset.source.title) \(preset.adjustmentLabel)mm")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                            }
                            .frame(width: 118, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background {
                                if isSelected {
                                    KeyboardKeyBackground(cornerRadius: 10, isSpecial: true, isAccent: true)
                                } else {
                                    KeyboardCardBackground(cornerRadius: 10)
                                }
                            }
                            .foregroundColor(isSelected ? .white : .primary)
                            .cornerRadius(10)
                        }
                        .simultaneousGesture(
                            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                                presetsStore.toggleFavorite(preset)
                            }
                        )
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

struct WeightSpecSelectorView: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Glass Build")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
                if let build = state.glassTypeState.confirmedBuild {
                    GlassTypeSummaryBadge(build: build)
                } else if let spec = state.selectedWeightSpec {
                    Text("\(GlassWeightCalculator.formattedDecimal(spec.arealDensityKgPerM2, scale: 1))kg/m2")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 16)

            if state.glassTypeState.confirmedBuild != nil {
                // Build is from Type tab — show a single chip reflecting it
                HStack(spacing: 8) {
                    Text(state.selectedWeightSpec?.name ?? "")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(KeyboardKeyBackground(cornerRadius: 10, isSpecial: true, isAccent: true))
                        .cornerRadius(10)
                    Spacer()
                    Button(action: {
                        state.glassTypeState.reset()
                        state.selectedWeightSpec = GlassWeightSpec.defaults.first
                    }) {
                        Text("Change")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(GlassWeightSpec.defaults) { spec in
                            let isSelected = state.selectedWeightSpec?.id == spec.id

                            Button(action: { state.selectedWeightSpec = spec }) {
                                Text(spec.name)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                                    .frame(height: 32)
                                    .padding(.horizontal, 12)
                                    .background {
                                        if isSelected {
                                            KeyboardKeyBackground(cornerRadius: 10, isSpecial: true, isAccent: true)
                                        } else {
                                            KeyboardCardBackground(cornerRadius: 10)
                                        }
                                    }
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

struct MeasurementDisplayView: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        VStack(spacing: 6) {
            if state.mode == .cutSize {
                let source = state.selectedPreset?.source ?? .sight
                HStack(spacing: 8) {
                    if source == .sight {
                        MeasurementCardView(
                            title: "Sight",
                            widthExpr: state.sightWidth,
                            heightExpr: state.sightHeight,
                            activeField: state.activeField,
                            widthField: .sightWidth,
                            heightField: .sightHeight,
                            onTap: { field in state.selectField(field) }
                        )
                        MeasurementCardView(
                            title: "Tight",
                            widthExpr: state.tightWidth,
                            heightExpr: state.tightHeight,
                            activeField: state.activeField,
                            widthField: .tightWidth,
                            heightField: .tightHeight,
                            isOptional: true,
                            onTap: { field in state.selectField(field) }
                        )
                    } else {
                        MeasurementCardView(
                            title: "Tight",
                            widthExpr: state.tightWidth,
                            heightExpr: state.tightHeight,
                            activeField: state.activeField,
                            widthField: .tightWidth,
                            heightField: .tightHeight,
                            onTap: { field in state.selectField(field) }
                        )
                        MeasurementCardView(
                            title: "Sight",
                            widthExpr: state.sightWidth,
                            heightExpr: state.sightHeight,
                            activeField: state.activeField,
                            widthField: .sightWidth,
                            heightField: .sightHeight,
                            isOptional: true,
                            onTap: { field in state.selectField(field) }
                        )
                    }
                }
                CutSummaryView(result: state.result, formulaSource: source)
            } else {
                WeightAutoDisplayView(state: state)
            }
        }
        .padding(.horizontal, 14)
    }
}

struct WeightMeasurementCardView: View {
    let widthExpr: String
    let heightExpr: String
    let activeField: MeasurementField
    let onTap: (MeasurementField) -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text("Glazing Size")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 4) {
                CompactFieldCellView(
                    title: "H",
                    expr: heightExpr,
                    isActive: activeField == .weightHeight,
                    onTap: { onTap(.weightHeight) }
                )

                Text("×")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)

                CompactFieldCellView(
                    title: "W",
                    expr: widthExpr,
                    isActive: activeField == .weightWidth,
                    onTap: { onTap(.weightWidth) }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .padding(.horizontal, 7)
        .padding(.vertical, 6)
        .background(KeyboardCardBackground(cornerRadius: 10))
        .cornerRadius(10)
    }
}

struct MeasurementCardView: View {
    let title: String
    let widthExpr: String
    let heightExpr: String
    let activeField: MeasurementField
    let widthField: MeasurementField
    let heightField: MeasurementField
    var isOptional: Bool = false
    let onTap: (MeasurementField) -> Void

    private var isCardActive: Bool {
        activeField == widthField || activeField == heightField
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isCardActive ? .accentColor : .secondary)
            }

            HStack(spacing: 4) {
                CompactFieldCellView(
                    title: "H",
                    expr: heightExpr,
                    isActive: activeField == heightField,
                    onTap: { onTap(heightField) }
                )

                Text("×")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.secondary)

                CompactFieldCellView(
                    title: "W",
                    expr: widthExpr,
                    isActive: activeField == widthField,
                    onTap: { onTap(widthField) }
                )
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .background(KeyboardCardBackground(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isCardActive ? Color.accentColor.opacity(0.50) : Color.clear, lineWidth: 1.5)
        )
        .cornerRadius(9)
    }
}

struct CompactFieldCellView: View {
    let title: String
    let expr: String
    let isActive: Bool
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var resolvedText: String {
        if expr.isEmpty { return "" }
        if let value = ExpressionParser.evaluate(expr), String(value) != expr {
            return "\(expr)=\(value)"
        }
        return expr
    }

    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(.secondary)

            Text(expr.isEmpty ? "—" : resolvedText)
                .font(.system(size: 13, weight: isActive ? .bold : .semibold))
                .foregroundColor(expr.isEmpty ? Color(UIColor.tertiaryLabel) : (isActive ? .accentColor : .primary))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, minHeight: 32)
        .background {
            if isActive {
                RoundedRectangle(cornerRadius: 7)
                    .fill(.thinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 7).fill(Color.accentColor.opacity(0.12)))
            } else {
                KeyboardCardBackground(cornerRadius: 7)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(
                    isActive
                    ? Color.accentColor.opacity(0.85)
                    : (colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.18)),
                    lineWidth: 1.5
                )
        )
        .onTapGesture { onTap() }
    }
}

struct CutSummaryView: View {
    let result: GlazingResult?
    var formulaSource: FormulaSource = .sight

    var body: some View {
        VStack(spacing: 0) {
            // ── Main row: cut size + adjustment ──────────────────────────
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Glazing Size")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)

                    if let result {
                        Text(result.cutSizeOnly.replacingOccurrences(of: "x", with: " × "))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        Text("Enter \(formulaSource.title) H and W")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                }

                Spacer(minLength: 8)

                if let result {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Adjustment")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text(result.adjustment > 0 ? "+\(result.adjustment)mm" : "\(result.adjustment)mm")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, result?.hasClearanceInfo == true ? 4 : 8)

            // ── Clearance row (only when data available) ──────────────────
            if let result, result.hasClearanceInfo {
                ClearanceRowView(clearance: result.clearance)
                    .padding(.horizontal, 10)
                    .padding(.bottom, (result.sightTightHeightDiff != nil && result.sightTightWidthDiff != nil) || result.sightTightInvestigateLabel != nil ? 2 : 7)
            }

            // ── Sight–Tight difference row ─────────────────────────────────
            if let result,
               result.sightTightHeightDiff != nil && result.sightTightWidthDiff != nil
               || result.sightTightInvestigateLabel != nil {
                SightTightDiffRowView(
                    heightDiff: result.sightTightHeightDiff,
                    widthDiff: result.sightTightWidthDiff,
                    investigateLabel: result.sightTightInvestigateLabel
                )
                    .padding(.horizontal, 10)
                    .padding(.bottom, 7)
            }
        }
        .frame(maxWidth: .infinity)
        .background { KeyboardCardBackground(cornerRadius: 12) }
        .cornerRadius(12)
    }
}

// MARK: - ClearanceRowView

private struct ClearanceRowView: View {
    let clearance: GlazingClearance

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 6) {
            // Label + values
            HStack(spacing: 4) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(labelColour)

                Text(titleText)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(labelColour)

                Text(valueText)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }

            Spacer(minLength: 4)

            // Status badge (only when both dims are present for comparison)
            if let status = consistencyStatus {
                HStack(spacing: 3) {
                    Image(systemName: statusIcon(status))
                        .font(.system(size: 9, weight: .bold))
                    Text(statusShortLabel(status))
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(statusColour(status))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(statusColour(status).opacity(colorScheme == .dark ? 0.18 : 0.10))
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(clearance.isOversize
                    ? Color.red.opacity(colorScheme == .dark ? 0.18 : 0.10)
                    : Color.secondary.opacity(colorScheme == .dark ? 0.10 : 0.06))
        )
    }

    // MARK: Helpers

    private var labelColour: Color {
        clearance.isOversize ? .red : .secondary
    }

    private var titleText: String {
        if clearance.isOversize { return "Oversize!" }
        if clearance.heightPerSideMm != nil { return "Clr" }
        return "Edge"
    }

    private var valueText: String {
        if clearance.isOversize {
            let h = clearance.heightPerSideMm.map { fmtMm($0) + "mm" } ?? "?"
            let w = clearance.widthPerSideMm.map  { fmtMm($0) + "mm" } ?? "?"
            return "H \(h)  W \(w) / side"
        }
        if let h = clearance.heightPerSideMm, let w = clearance.widthPerSideMm {
            let hStr = fmtMm(h)
            let wStr = fmtMm(w)
            return abs(h - w) < 0.5 ? "\(hStr)mm/side" : "H \(hStr)  W \(wStr)mm"
        }
        if let h = clearance.heightPerSideMm { return "\(fmtMm(h))mm/side" }
        if let h = clearance.heightOverlapMm, let w = clearance.widthOverlapMm {
            let hStr = fmtMm(h)
            let wStr = fmtMm(w)
            return abs(h - w) < 0.5 ? "\(hStr)mm/side" : "H \(hStr)  W \(wStr)mm"
        }
        if let h = clearance.heightOverlapMm { return "\(fmtMm(h))mm/side" }
        return ""
    }

    private var consistencyStatus: GlazingClearance.Status? {
        // Always show badge when oversize
        if clearance.isOversize { return .oversize }
        // Only show status badge when we have both H and W to compare
        guard clearance.heightPerSideMm != nil && clearance.widthPerSideMm != nil
           || clearance.heightOverlapMm != nil && clearance.widthOverlapMm != nil
        else { return nil }
        let s = clearance.status
        // Don't show a badge if they're the same value (tight-only formula gives identical dims)
        if let delta = clearance.delta, delta < 0.5 { return nil }
        return s
    }

    private func statusIcon(_ s: GlazingClearance.Status) -> String {
        switch s {
        case .ok:        return "checkmark.circle.fill"
        case .check:     return "exclamationmark.triangle.fill"
        case .remeasure: return "exclamationmark.triangle.fill"
        case .oversize:  return "xmark.circle.fill"
        }
    }

    private func statusShortLabel(_ s: GlazingClearance.Status) -> String {
        switch s {
        case .ok:        return "Consistent"
        case .check:     return "Check"
        case .remeasure: return "Re-measure!"
        case .oversize:  return "Won't fit!"
        }
    }

    private func statusColour(_ s: GlazingClearance.Status) -> Color {
        switch s {
        case .ok:        return .green
        case .check:     return .orange
        case .remeasure: return .red
        case .oversize:  return .red
        }
    }

    private func fmtMm(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

// MARK: - SightTightDiffRowView

private struct SightTightDiffRowView: View {
    let heightDiff: Int?
    let widthDiff: Int?
    let investigateLabel: String?

    @Environment(\.colorScheme) private var colorScheme

    // One measurement is missing — user needs to go get it
    private var isInvestigate: Bool { investigateLabel != nil }
    // Both present but zero — sight == tight, suspicious
    private var isZeroDiff: Bool { heightDiff == 0 && widthDiff == 0 }
    private var isConsistent: Bool {
        guard let h = heightDiff, let w = widthDiff else { return false }
        return !isZeroDiff && abs(h - w) <= 3
    }

    private var badgeColour: Color {
        if isInvestigate { return .orange }
        if isZeroDiff    { return .orange }
        return isConsistent ? .green : .orange
    }
    private var badgeLabel: String {
        if isInvestigate { return "Investigate" }
        if isZeroDiff    { return "Sight = Tight?" }
        return isConsistent ? "Consistent" : "Check"
    }
    private var badgeIcon: String {
        if isInvestigate { return "magnifyingglass" }
        if isZeroDiff    { return "exclamationmark.triangle.fill" }
        return isConsistent ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.and.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
            Text("S↔T")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
            if let label = investigateLabel {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            } else if let h = heightDiff, let w = widthDiff {
                Text("H \(h)mm  W \(w)mm")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
            }
            Spacer(minLength: 4)
            HStack(spacing: 3) {
                Image(systemName: badgeIcon)
                    .font(.system(size: 9, weight: .bold))
                Text(badgeLabel)
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundColor(badgeColour)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(badgeColour.opacity(colorScheme == .dark ? 0.18 : 0.10)))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(colorScheme == .dark ? 0.10 : 0.06))
        )
    }
}

struct WeightSummaryView: View {
    let result: GlassWeightResult?

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Estimated Weight")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                if let result {
                    Text("\(result.weightLabel) kg")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("Enter width and height")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                }
            }

            Spacer(minLength: 8)

            if let result {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Area")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("\(result.areaLabel)m2")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                    Text(result.handlingRecommendation)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(KeyboardCardBackground(cornerRadius: 12))
        .cornerRadius(12)
    }
}

// MARK: - WeightAutoDisplayView

struct WeightAutoDisplayView: View {
    @ObservedObject var state: KeyboardState

    private var build: GlassBuild? { state.glassTypeState.confirmedBuild }
    private var sizing: GlazingResult? { state.result }

    var body: some View {
        VStack(spacing: 6) {
            if let result = state.autoWeightResult, let build = build {
                weightCard(result: result, build: build)
            } else {
                if build == nil {
                    promptCard(
                        icon: "square.3.layers.3d.top.filled",
                        text: "Select a glass type in the Type tab"
                    )
                }
                if sizing == nil {
                    promptCard(
                        icon: "ruler",
                        text: "Calculate a glazing size in the Size tab"
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func weightCard(result: GlassWeightResult, build: GlassBuild) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1: glass type + size
            HStack(spacing: 6) {
                GlassTypeSummaryBadge(build: build)
                Spacer(minLength: 4)
                if let sizing {
                    Text("\(sizing.cutHeight) × \(sizing.cutWidth)mm")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }

            // Row 2: weight + area + handling
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(result.weightLabel)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("kg")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text("Area \(result.areaLabel)m²")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text(result.handlingRecommendation)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(KeyboardCardBackground(cornerRadius: 12))
        .cornerRadius(12)
    }

    private func promptCard(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 54)
        .background(KeyboardCardBackground(cornerRadius: 10))
        .cornerRadius(10)
    }
}

struct NumpadView: View {
    @ObservedObject var state: KeyboardState
    @ObservedObject var clipboardStore: ClipboardHistoryStore
    let onInsert: (String) -> Void
    let onSwitchKeyboard: () -> Void
    let onSettings: () -> Void
    let onDelete: () -> Void

    private let keyHeight: CGFloat = 36
    private let keySpacing: CGFloat = 5
    private let sidePadding: CGFloat = 14
    private let topPadding: CGFloat = 6
    private let bottomPadding: CGFloat = 2

    // Right column: row 0 = backspace (keyboard-only), rows 1-2 = host-targeting
    private let rows: [[KeypadKey]] = [
        [.digit("1"), .digit("2"), .digit("3"), .backspace],
        [.digit("4"), .digit("5"), .digit("6"), .hostDelete],
        [.digit("7"), .digit("8"), .digit("9"), .lineBreak],
    ]
    // Bottom row: globe + 0 + insert (rendered at 2× width)
    private let bottomRow: [KeypadKey] = [.abc, .digit("0")]

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width - (sidePadding * 2) - (keySpacing * 3), 0)
            let keyWidth = floor(availableWidth / 4)

            VStack(spacing: keySpacing) {
                // Rows 0-2: standard 4-column grid
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: keySpacing) {
                        ForEach(rows[rowIndex].indices, id: \.self) { columnIndex in
                            let key = rows[rowIndex][columnIndex]
                            KeypadButtonView(
                                key: key,
                                onTap: { handleKey(key) },
                                onLongPress: nil,
                                onSettings: onSettings
                            )
                            .frame(width: keyWidth, height: keyHeight)
                        }
                    }
                }
                // Bottom row: globe + 0 + insert (2× wide, fills columns 2–3)
                HStack(spacing: keySpacing) {
                    ForEach(bottomRow.indices, id: \.self) { idx in
                        let key = bottomRow[idx]
                        KeypadButtonView(
                            key: key,
                            onTap: { handleKey(key) },
                            onLongPress: nil,
                            onSettings: onSettings
                        )
                        .frame(width: keyWidth, height: keyHeight)
                    }
                    KeypadButtonView(
                        key: .insert,
                        onTap: { handleKey(.insert) },
                        onLongPress: handleLongPressInsert,
                        onSettings: onSettings
                    )
                    .frame(width: keyWidth * 2 + keySpacing, height: keyHeight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, sidePadding)
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
        }
        .frame(height: 167)
    }

    private func handleKey(_ key: KeypadKey) {
        switch key {
        case .digit(let digit):
            if state.mode == .glassType {
                state.glassTypeState.appendToSearch(digit)
            } else {
                state.appendToActive(digit)
            }
        case .lineBreak:
            onInsert("\n")
        case .hostDelete:
            onDelete()
        case .backspace:
            if state.mode == .glassType {
                state.glassTypeState.deleteFromSearch()
            } else {
                state.deleteFromActive()
            }
        case .spacer:
            break
        case .insert:
            insertRecord(full: true)
        case .globe:
            onSwitchKeyboard()
        case .abc:
            onSwitchKeyboard()
        case .settings:
            onSettings()
        }
    }

    private func handleLongPressInsert() {
        insertRecord(full: false)
    }

    private func insertRecord(full: Bool) {
        let text: String
        switch state.mode {
        case .glassType:
            // In Type tab, insert just advances to Size tab
            state.setMode(.cutSize)
            return
        case .cutSize:
            guard let result = state.result else { return }
            // Tap = full multi-line record; long-press = "1@ WxH"
            text = full ? result.formattedRecord : result.cutSizeRecord
        case .weight:
            guard let result = state.autoWeightResult else { return }
            // Tap = weight only; long-press = full record
            text = full ? "\(result.weightLabel)kg" : result.formattedRecord
        }
        clipboardStore.add(text, modeLabel: state.mode.title)
        onInsert(text)
        state.reset()
    }
}

enum KeypadKey: Equatable {
    case digit(String)
    case lineBreak
    case hostDelete
    case backspace
    case spacer
    case insert
    case globe
    case abc
    case settings
}

struct KeypadButtonView: View {
    let key: KeypadKey
    @EnvironmentObject private var keyboardContext: KeyboardContext
    let onTap: () -> Void
    let onLongPress: (() -> Void)?
    let onSettings: () -> Void

    private var label: String {
        switch key {
        case .digit(let digit): return digit
        case .lineBreak: return "↵"
        case .hostDelete: return ""
        case .backspace: return ""
        case .spacer: return ""
        case .insert: return "✓"
        case .globe: return "🌐"
        case .abc: return "ABC"
        case .settings: return "⚙️"
        }
    }

    private var isSpecial: Bool {
        switch key {
        case .hostDelete, .lineBreak, .globe, .abc, .settings:
            return true
        default:
            return false
        }
    }

    private var isInsert: Bool {
        key == .insert
    }

    private var isGlobe: Bool {
        key == .globe || key == .abc
    }

    var body: some View {
        if key == .spacer {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isGlobe && !keyboardContext.needsInputModeSwitchKey {
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KeyboardKeyBackground(cornerRadius: 10, isSpecial: true, isAccent: false))
                    .cornerRadius(10)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Button(action: onTap) {
                keyButtonLabel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(KeyboardKeyBackground(cornerRadius: 10, isSpecial: isSpecial, isAccent: isInsert))
                    .foregroundColor(isInsert ? .white : .primary)
                    .cornerRadius(10)
            }
            .if(onLongPress != nil) { view in
                view.simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.6).onEnded { _ in
                        onLongPress?()
                    }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var keyButtonLabel: some View {
        switch key {
        case .backspace:
            // Deletes from the active measurement field
            Image(systemName: "delete.backward")
                .font(.system(size: 17))
        case .hostDelete:
            // Sends delete to the host document (filled = document-level action)
            Image(systemName: "delete.backward.fill")
                .font(.system(size: 17))
        default:
            Text(label)
                .font(.system(size: isInsert ? 18 : 17, weight: isInsert ? .bold : .regular))
        }
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}