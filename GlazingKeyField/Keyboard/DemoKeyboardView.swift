import SwiftUI

private enum KeyboardLayoutMetrics {
    static let modeSelectorHeight: CGFloat = 28
    static let selectorHeight: CGFloat = 60
    // 132pt: cards have outer .padding(.vertical, 4/6) after .frame(height:52),
    // so their layout height is 60pt (cut) / 64pt (weight). Max mode = 64+6+58=128, +4pt buffer.
    static let measurementHeight: CGFloat = 132
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
    case cutSize
    case weight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cutSize: return "Glazing"
        case .weight: return "Weight"
        }
    }
}

final class KeyboardState: ObservableObject {
    @Published var mode: KeyboardMode = .cutSize
    @Published var sightWidth: String = ""
    @Published var sightHeight: String = ""
    @Published var tightWidth: String = ""
    @Published var tightHeight: String = ""
    @Published var weightWidth: String = ""
    @Published var weightHeight: String = ""
    @Published var activeField: MeasurementField = .sightHeight
    @Published var showSettings = false
    @Published var selectedPreset: GlassPreset?
    @Published var selectedWeightSpec: GlassWeightSpec?

    private var autoFilledWeightHeight = ""
    private var autoFilledWeightWidth = ""

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
        setValue(value(for: activeField) + char, for: activeField)
    }

    func deleteFromActive() {
        var current = value(for: activeField)
        if !current.isEmpty {
            current.removeLast()
        }
        setValue(current, for: activeField)
    }

    func clearActive() {
        setValue("", for: activeField)
    }

    var modeFields: [MeasurementField] {
        switch mode {
        case .cutSize:
            return [.sightHeight, .sightWidth, .tightHeight, .tightWidth]
        case .weight:
            return [.weightHeight, .weightWidth]
        }
    }

    func setMode(_ newMode: KeyboardMode) {
        mode = newMode
        if newMode == .weight {
            prepopulateWeightFromGlazingIfAvailable()
        }
        if !modeFields.contains(activeField), let first = modeFields.first {
            activeField = first
        }
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
        switch mode {
        case .cutSize:
            sightWidth = ""
            sightHeight = ""
            tightWidth = ""
            tightHeight = ""
            activeField = .sightHeight
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
}

struct KeyboardRootView: View {
    @ObservedObject var presetsStore: PresetsStore
    @ObservedObject var diagnostics: KeyboardDiagnostics
    @ObservedObject var renderState: KeyboardRenderState
    let keyboardHeight: CGFloat
    let onInsert: (String) -> Void
    let onSwitchKeyboard: () -> Void
    let onDelete: () -> Void

    @StateObject private var state = KeyboardState()
    @AppStorage(KeyboardPreferences.debugModeKey, store: UserDefaults.standard) private var isDebugModeEnabled = false

    init(
        presetsStore: PresetsStore,
        diagnostics: KeyboardDiagnostics,
        renderState: KeyboardRenderState,
        keyboardHeight: CGFloat,
        onInsert: @escaping (String) -> Void,
        onSwitchKeyboard: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.presetsStore = presetsStore
        self.diagnostics = diagnostics
        self.renderState = renderState
        self.keyboardHeight = keyboardHeight
        self.onInsert = onInsert
        self.onSwitchKeyboard = onSwitchKeyboard
        self.onDelete = onDelete
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
        .overlay(alignment: .topLeading) {
            if isDebugModeEnabled {
                KeyboardDiagnosticsOverlayView(diagnostics: diagnostics)
            }
        }
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
                } else {
                    keyboardContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipShape(RoundedCorner(radius: KeyboardLayoutMetrics.shellCornerRadius, corners: [.topLeft, .topRight]))
    }

    private var keyboardContent: some View {
        VStack(spacing: KeyboardLayoutMetrics.sectionSpacing) {
            ModeSelectorView(state: state)
            ZStack(alignment: .top) {
                if state.mode == .cutSize {
                    GlassTypeSelectorView(presetsStore: presetsStore, state: state)
                } else {
                    WeightSpecSelectorView(state: state)
                }
            }
            .frame(height: KeyboardLayoutMetrics.selectorHeight, alignment: .top)
            .clipped()

            MeasurementDisplayView(state: state)
                .frame(height: KeyboardLayoutMetrics.measurementHeight, alignment: .top)

            NumpadView(
                state: state,
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
                // Special keys blend into keyboard background (iOS convention)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark
                        ? Color(red: 0.118, green: 0.118, blue: 0.125)
                        : Color(red: 0.675, green: 0.698, blue: 0.741))
            } else {
                // Regular keys: white light / elevated dark grey
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark
                        ? Color(red: 0.216, green: 0.216, blue: 0.235)
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
                .onChange(of: proxy.size) { newSize in
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
                        ? Color(red: 0.216, green: 0.216, blue: 0.235)
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
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundColor(state.mode == mode ? .primary : .secondary)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
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
                    Text(preset.adjustmentLabel + "mm")
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
                                Text(preset.adjustmentLabel + "mm")
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
                                    KeyboardPanelBackground(cornerRadius: 10)
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
                if let spec = state.selectedWeightSpec {
                    Text("\(GlassWeightCalculator.formattedDecimal(spec.arealDensityKgPerM2, scale: 1))kg/m2")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 16)

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
                                        KeyboardPanelBackground(cornerRadius: 10)
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

struct MeasurementDisplayView: View {
    @ObservedObject var state: KeyboardState

    var body: some View {
        VStack(spacing: 6) {
            if state.mode == .cutSize {
                HStack(spacing: 8) {
                    MeasurementCardView(
                        title: "Sight",
                        widthExpr: state.sightWidth,
                        heightExpr: state.sightHeight,
                        activeField: state.activeField,
                        widthField: .sightWidth,
                        heightField: .sightHeight,
                        onTap: { field in state.activeField = field }
                    )

                    MeasurementCardView(
                        title: "Tight",
                        widthExpr: state.tightWidth,
                        heightExpr: state.tightHeight,
                        activeField: state.activeField,
                        widthField: .tightWidth,
                        heightField: .tightHeight,
                        onTap: { field in state.activeField = field }
                    )
                }
                CutSummaryView(result: state.result)
            } else {
                WeightMeasurementCardView(
                    widthExpr: state.weightWidth,
                    heightExpr: state.weightHeight,
                    activeField: state.activeField,
                    onTap: { field in state.activeField = field }
                )
                WeightSummaryView(result: state.weightResult)
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
            Text("Panel Size")
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
        .background(KeyboardPanelBackground(cornerRadius: 10))
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
    let onTap: (MeasurementField) -> Void

    private var isCardActive: Bool {
        activeField == widthField || activeField == heightField
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isCardActive ? .accentColor : .secondary)

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
        .background(KeyboardPanelBackground(cornerRadius: 9, lightOverlayOpacity: 0.07, darkOverlayOpacity: 0.16))
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
                KeyboardPanelBackground(cornerRadius: 7, lightOverlayOpacity: 0.06, darkOverlayOpacity: 0.14)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(
                    isActive
                    ? Color.accentColor.opacity(0.85)
                    : (colorScheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.10)),
                    lineWidth: 1.5
                )
        )
        .onTapGesture { onTap() }
    }
}

struct CutSummaryView: View {
    let result: GlazingResult?

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Glazing Size")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)

                if let result {
                    Text(result.cutSizeOnly.replacingOccurrences(of: "x", with: " × "))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("Enter sight and tight sizes")
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
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background {
            KeyboardPanelBackground(cornerRadius: 12)
            if result != nil {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.green.opacity(0.09))
            }
        }
        .cornerRadius(12)
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
        .background(KeyboardPanelBackground(cornerRadius: 12))
        .cornerRadius(12)
    }
}

struct NumpadView: View {
    @ObservedObject var state: KeyboardState
    @EnvironmentObject private var keyboardContext: KeyboardContext
    let onInsert: (String) -> Void
    let onSwitchKeyboard: () -> Void
    let onSettings: () -> Void
    let onDelete: () -> Void

    private let keyHeight: CGFloat = 36
    private let keySpacing: CGFloat = 5
    private let sidePadding: CGFloat = 14
    private let topPadding: CGFloat = 6
    private let bottomPadding: CGFloat = 2

    private let rows: [[KeypadKey]] = [
        [.digit("1"), .digit("2"), .digit("3"), .backspace],
        [.digit("4"), .digit("5"), .digit("6"), .hostDelete],
        [.digit("7"), .digit("8"), .digit("9"), .spacer],
        [.globe, .digit("0"), .lineBreak, .insert]
    ]

    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width - (sidePadding * 2) - (keySpacing * 3), 0)
            let keyWidth = floor(availableWidth / 4)

            VStack(spacing: keySpacing) {
                ForEach(rows.indices, id: \.self) { rowIndex in
                    HStack(spacing: keySpacing) {
                        ForEach(rows[rowIndex].indices, id: \.self) { columnIndex in
                            let key = rows[rowIndex][columnIndex]
                            KeypadButtonView(
                                key: key,
                                onTap: { handleKey(key) },
                                onLongPress: key == .insert ? handleLongPressInsert : nil,
                                onSettings: onSettings
                            )
                            .frame(width: keyWidth, height: keyHeight)
                        }
                    }
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
            state.appendToActive(digit)
        case .lineBreak:
            onInsert("\n")
        case .hostDelete:
            onDelete()
        case .backspace:
            state.deleteFromActive()
        case .spacer:
            break
        case .insert:
            insertRecord(full: true)
        case .globe:
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
        case .cutSize:
            guard let result = state.result else { return }
            text = full ? result.formattedRecord : result.cutSizeOnly
        case .weight:
            guard let result = state.weightResult else { return }
            text = full ? result.formattedRecord : "\(result.weightLabel)kg"
        }
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
        case .settings: return "⚙️"
        }
    }

    private var isSpecial: Bool {
        if case .digit = key {
            return false
        }
        return true
    }

    private var isInsert: Bool {
        key == .insert
    }

    private var isGlobe: Bool {
        key == .globe
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