import Foundation
import SwiftUI

enum ExpressionParser {

    static func evaluate(_ input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        var result = 0
        var current = ""
        var isFirst = true

        for character in trimmed {
            if (character == "+" || character == "-"), !isFirst {
                guard let value = Int(current.trimmingCharacters(in: .whitespaces)) else {
                    return nil
                }
                result += value
                current = String(character)
            } else {
                current.append(character)
            }
            isFirst = false
        }

        guard let value = Int(current.trimmingCharacters(in: .whitespaces)) else {
            return nil
        }
        return result + value
    }
}

/// Which measurement the formula is applied to when calculating the glazing cut size.
enum FormulaSource: String, Codable, CaseIterable, Identifiable {
    case sight
    case tight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sight: return "Sight"
        case .tight: return "Tight"
        }
    }

    var opposite: FormulaSource {
        self == .sight ? .tight : .sight
    }
}

// MARK: - GlazingClearance

struct GlazingClearance {
    /// Gap between glass edge and the rebate stop on each side (mm).
    /// Derived from tight measurement when available.
    let heightPerSideMm: Double?
    let widthPerSideMm: Double?

    /// How far the glass extends past the sight line into the rebate on each side (mm).
    /// Derived from sight measurement when available.
    let heightOverlapMm: Double?
    let widthOverlapMm: Double?

    /// Absolute difference in clearance between the height and width dimensions.
    var delta: Double? {
        guard let h = heightPerSideMm, let w = widthPerSideMm else { return nil }
        return abs(h - w)
    }

    /// True when the cut glass is larger than the frame opening (glass won't fit).
    var isOversize: Bool {
        if let h = heightPerSideMm, h < 0 { return true }
        if let w = widthPerSideMm,  w < 0 { return true }
        return false
    }

    enum Status {
        case ok                  // delta < 2mm or only one dim
        case check               // 2–5mm delta
        case remeasure           // ≥ 5mm delta
        case oversize            // clearance is negative — glass > frame

        var symbol: String {
            switch self {
            case .ok:        return "✓"
            case .check:     return "⚠"
            case .remeasure: return "⚠"
            case .oversize:  return "✗"
            }
        }

        var label: String {
            switch self {
            case .ok:        return "Consistent"
            case .check:     return "Check measurements"
            case .remeasure: return "Re-measure!"
            case .oversize:  return "Glass too large!"
            }
        }
    }

    var status: Status {
        if isOversize { return .oversize }
        guard let d = delta else { return .ok }
        if d < 2 { return .ok }
        if d < 5 { return .check }
        return .remeasure
    }

    /// Compact description for the print record.
    var printSummary: String {
        if isOversize {
            let h = heightPerSideMm.map { fmtMm($0) + "mm" } ?? "?"
            let w = widthPerSideMm.map  { fmtMm($0) + "mm" } ?? "?"
            return "⚠ Glass oversize: H \(h)/side  W \(w)/side — glass LARGER than tight opening"
        }
        if let h = heightPerSideMm, let w = widthPerSideMm {
            let hStr = fmtMm(h)
            let wStr = fmtMm(w)
            let dims = abs(h - w) < 0.5 ? "\(hStr)mm/side" : "H=\(hStr)mm W=\(wStr)mm"
            return "Clr: \(dims) (\(status.symbol) \(status.label))"
        }
        if let h = heightPerSideMm { return "Clr: \(fmtMm(h))mm/side" }
        if let h = heightOverlapMm, let w = widthOverlapMm {
            let hStr = fmtMm(h)
            let wStr = fmtMm(w)
            return abs(h - w) < 0.5
                ? "Rebate edge: \(hStr)mm/side"
                : "Rebate edge: H=\(hStr)mm W=\(wStr)mm"
        }
        if let h = heightOverlapMm { return "Rebate edge: \(fmtMm(h))mm/side" }
        return ""
    }

    private func fmtMm(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(v))" : String(format: "%.1f", v)
    }
}

// MARK: - GlazingResult

struct GlazingResult {
    /// Source measurement (required). Opposite is optional — only present if user entered it.
    let sightWidth: Int?
    let sightHeight: Int?
    let tightWidth: Int?
    let tightHeight: Int?
    let cutWidth: Int
    let cutHeight: Int
    let adjustment: Int
    let presetName: String
    let calculationSource: FormulaSource
    let hasOppositeMeasurement: Bool

    // MARK: Clearance

    var clearance: GlazingClearance {
        // Clearance per side from tight (gap between glass edge and rebate stop)
        let hClr: Double? = tightHeight.map { Double($0 - cutHeight) / 2.0 }
        let wClr: Double? = tightWidth.map  { Double($0 - cutWidth)  / 2.0 }

        // Overlap per side from sight (how far glass extends past sight line into rebate)
        let hOlp: Double? = sightHeight.map { Double(cutHeight - $0) / 2.0 }
        let wOlp: Double? = sightWidth.map  { Double(cutWidth  - $0) / 2.0 }

        return GlazingClearance(
            heightPerSideMm: hClr,
            widthPerSideMm:  wClr,
            heightOverlapMm: hOlp,
            widthOverlapMm:  wOlp
        )
    }

    /// True when there is enough data to display a clearance value on-screen.
    var hasClearanceInfo: Bool {
        let c = clearance
        return c.heightPerSideMm != nil || c.heightOverlapMm != nil
    }

    // MARK: Sight–Tight difference

    /// Positive when tight > sight (normal: tight is the frame opening, sight is the visible opening)
    var sightTightHeightDiff: Int? {
        guard let sh = sightHeight, let th = tightHeight else { return nil }
        return th - sh
    }

    var sightTightWidthDiff: Int? {
        guard let sw = sightWidth, let tw = tightWidth else { return nil }
        return tw - sw
    }

    /// True when height and width diffs are within 3mm of each other (consistent rebate all round)
    var sightTightDiffConsistent: Bool? {
        guard let h = sightTightHeightDiff, let w = sightTightWidthDiff else { return nil }
        return abs(h - w) <= 3
    }

    /// Non-nil when exactly one of sight/tight is present — prompt to measure the missing one.
    var sightTightInvestigateLabel: String? {
        let hasSight = sightHeight != nil
        let hasTight = tightHeight != nil
        if hasSight && !hasTight { return "Measure tight opening" }
        if hasTight && !hasSight { return "Measure sight opening" }
        return nil
    }

    // MARK: Record text

    var formattedRecord: String {
        var lines = ["1@ \(cutSizeOnly)", ""]
        if let sw = sightWidth, let sh = sightHeight {
            let label = calculationSource == .sight ? "Sight*" : "Sight"
            lines.append("\(label): \(sh)x\(sw)")
        }
        if let tw = tightWidth, let th = tightHeight {
            let label = calculationSource == .tight ? "Tight*" : "Tight"
            lines.append("\(label): \(th)x\(tw)")
        }
        lines.append("Formula: \(formulaAdjustment)")
        if let hd = sightTightHeightDiff, let wd = sightTightWidthDiff {
            let consistent = abs(hd - wd) <= 3
            let status = consistent ? "✓ Consistent" : "⚠ Check"
            lines.append("Diff: H \(hd)mm  W \(wd)mm  \(status)")
        }
        let summary = clearance.printSummary
        if !summary.isEmpty { lines.append(summary) }
        return lines.joined(separator: "\n")
    }

    var cutSizeOnly: String {
        "\(cutHeight)x\(cutWidth)"
    }

    var cutSizeRecord: String {
        "1@ \(cutSizeOnly)"
    }

    private var formulaAdjustment: String {
        adjustment > 0 ? "(+\(adjustment))" : "(\(adjustment))"
    }
}

struct GlazingCalculator {

    /// Calculates the glazing cut size from expression strings.
    /// Only the `preset.source` measurement pair is required; the opposite is optional.
    /// Returns `nil` if the required pair cannot be parsed or is zero.
    static func calculate(
        sightWidthExpr: String,
        sightHeightExpr: String,
        tightWidthExpr: String,
        tightHeightExpr: String,
        preset: GlassPreset
    ) -> GlazingResult? {
        let source = preset.source

        // Parse the required (source) measurement pair
        let srcWidthExpr  = source == .sight ? sightWidthExpr  : tightWidthExpr
        let srcHeightExpr = source == .sight ? sightHeightExpr : tightHeightExpr
        guard
            let srcWidth  = ExpressionParser.evaluate(srcWidthExpr),  srcWidth  > 0,
            let srcHeight = ExpressionParser.evaluate(srcHeightExpr), srcHeight > 0
        else { return nil }

        // Parse the optional opposite measurement pair
        let oppWidthExpr  = source == .sight ? tightWidthExpr  : sightWidthExpr
        let oppHeightExpr = source == .sight ? tightHeightExpr : sightHeightExpr
        let oppWidth  = ExpressionParser.evaluate(oppWidthExpr)
        let oppHeight = ExpressionParser.evaluate(oppHeightExpr)
        let hasOpposite = oppWidth != nil && oppHeight != nil

        let sightW: Int? = source == .sight ? srcWidth  : oppWidth
        let sightH: Int? = source == .sight ? srcHeight : oppHeight
        let tightW: Int? = source == .tight ? srcWidth  : oppWidth
        let tightH: Int? = source == .tight ? srcHeight : oppHeight

        return GlazingResult(
            sightWidth:  sightW,
            sightHeight: sightH,
            tightWidth:  tightW,
            tightHeight: tightH,
            cutWidth:  srcWidth  + preset.adjustment,
            cutHeight: srcHeight + preset.adjustment,
            adjustment: preset.adjustment,
            presetName: preset.name,
            calculationSource: source,
            hasOppositeMeasurement: hasOpposite
        )
    }
}

struct GlassWeightSpec: Identifiable, Equatable {
    let id: String
    let name: String
    let arealDensityKgPerM2: Decimal

    static let defaults: [GlassWeightSpec] = [
        GlassWeightSpec(id: "single_4", name: "Single 4mm", arealDensityKgPerM2: 10),
        GlassWeightSpec(id: "single_6", name: "Single 6mm", arealDensityKgPerM2: 15),
        GlassWeightSpec(id: "single_10", name: "Single 10mm", arealDensityKgPerM2: 25),
        GlassWeightSpec(id: "dgu_4_16_4", name: "DGU 4-16-4", arealDensityKgPerM2: 20),
        GlassWeightSpec(id: "lam_638", name: "Laminate 6.38mm", arealDensityKgPerM2: 16)
    ]
}

struct GlassWeightResult {
    let widthMm: Int
    let heightMm: Int
    let areaM2: Decimal
    let weightKg: Decimal
    let specName: String

    var areaLabel: String {
        GlassWeightCalculator.formattedDecimal(areaM2, scale: 3)
    }

    var weightLabel: String {
        GlassWeightCalculator.formattedDecimal(weightKg, scale: 1)
    }

    var handlingRecommendation: String {
        switch NSDecimalNumber(decimal: weightKg).doubleValue {
        case ..<25:
            return "Single person lift"
        case ..<50:
            return "Two person lift"
        case ..<90:
            return "Team/manual aid"
        default:
            return "Mechanical lift recommended"
        }
    }

    var formattedRecord: String {
        "Glass: \(specName) | Size: \(heightMm)x\(widthMm) | Area: \(areaLabel)m2 | Weight: \(weightLabel)kg | Handling: \(handlingRecommendation)"
    }
}

enum GlassWeightCalculator {

    static func calculate(widthExpr: String, heightExpr: String, spec: GlassWeightSpec) -> GlassWeightResult? {
        guard
            let width = ExpressionParser.evaluate(widthExpr),
            let height = ExpressionParser.evaluate(heightExpr)
        else {
            return nil
        }
        return calculate(widthMm: width, heightMm: height, spec: spec)
    }

    static func calculate(widthMm: Int, heightMm: Int, spec: GlassWeightSpec) -> GlassWeightResult? {
        guard widthMm > 0, heightMm > 0 else { return nil }

        let widthMeters = Decimal(widthMm) / 1000
        let heightMeters = Decimal(heightMm) / 1000
        let area = widthMeters * heightMeters
        let weight = area * spec.arealDensityKgPerM2

        return GlassWeightResult(
            widthMm: widthMm,
            heightMm: heightMm,
            areaM2: area,
            weightKg: weight,
            specName: spec.name
        )
    }

    static func formattedDecimal(_ value: Decimal, scale: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = scale
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0"
    }
}

struct GlassPreset: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var adjustment: Int
    /// Which measurement the formula is applied to when computing the glazing cut size.
    var source: FormulaSource
    /// Built-in presets are not deletable by the user.
    var isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, adjustment: Int, source: FormulaSource = .sight, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.adjustment = adjustment
        self.source = source
        self.isBuiltIn = isBuiltIn
    }

    var adjustmentLabel: String {
        adjustment > 0 ? "+\(adjustment)" : "\(adjustment)"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case adjustment
        case source
        case isBuiltIn
        case deductions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)

        let adj: Int
        if let a = try container.decodeIfPresent(Int.self, forKey: .adjustment) {
            adj = a
        } else {
            let oldDeductions = try container.decodeIfPresent([String: Int].self, forKey: .deductions) ?? [:]
            adj = oldDeductions["uPVC"] ?? oldDeductions.values.first ?? 0
        }
        adjustment = adj
        source = try container.decodeIfPresent(FormulaSource.self, forKey: .source) ?? (adj >= 0 ? .sight : .tight)
        isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(adjustment, forKey: .adjustment)
        try container.encode(source, forKey: .source)
        try container.encode(isBuiltIn, forKey: .isBuiltIn)
    }
}

extension GlassPreset {
    static let defaults: [GlassPreset] = [
        GlassPreset(name: "Double Glazing",   adjustment:  24, source: .sight, isBuiltIn: true),
        GlassPreset(name: "Single Aluminium", adjustment: -12, source: .tight, isBuiltIn: true),
        GlassPreset(name: "Single Timber",    adjustment:  -2, source: .tight, isBuiltIn: true)
    ]
}

final class PresetsStore: ObservableObject {

    private let defaultsKey = "glazing_presets_v1"
    private let favoritesKey = "glazing_preset_favorites_v1"
    private let recentsKey = "glazing_preset_recents_v1"
    private let maxRecentCount = 8
    private let defaults: UserDefaults

    @Published var presets: [GlassPreset] = []
    @Published var favoritePresetIDs: Set<UUID> = []
    @Published var recentPresetIDs: [UUID] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        presets = load()
        favoritePresetIDs = loadFavorites()
        recentPresetIDs = loadRecents()
    }

    func save() {
        guard let data = try? JSONEncoder().encode(presets) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    func add(_ preset: GlassPreset) {
        presets.append(preset)
        save()
    }

    func update(_ preset: GlassPreset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index] = preset
        save()
    }

    func delete(at offsets: IndexSet) {
        let removedIDs = offsets.compactMap { presets.indices.contains($0) ? presets[$0].id : nil }
        for index in offsets.sorted(by: >) {
            presets.remove(at: index)
        }
        favoritePresetIDs.subtract(removedIDs)
        recentPresetIDs.removeAll(where: { removedIDs.contains($0) })
        save()
        saveFavorites()
        saveRecents()
    }

    func move(from source: IndexSet, to destination: Int) {
        let items = source.sorted().map { presets[$0] }
        for index in source.sorted(by: >) {
            presets.remove(at: index)
        }
        var adjustedDestination = destination
        for index in source where index < destination {
            adjustedDestination -= 1
        }
        let insertionIndex = max(0, min(adjustedDestination, presets.count))
        presets.insert(contentsOf: items, at: insertionIndex)
        save()
    }

    func isFavorite(_ preset: GlassPreset) -> Bool {
        favoritePresetIDs.contains(preset.id)
    }

    func toggleFavorite(_ preset: GlassPreset) {
        if favoritePresetIDs.contains(preset.id) {
            favoritePresetIDs.remove(preset.id)
        } else {
            favoritePresetIDs.insert(preset.id)
        }
        saveFavorites()
    }

    func markRecent(_ preset: GlassPreset) {
        recentPresetIDs.removeAll(where: { $0 == preset.id })
        recentPresetIDs.insert(preset.id, at: 0)
        if recentPresetIDs.count > maxRecentCount {
            recentPresetIDs = Array(recentPresetIDs.prefix(maxRecentCount))
        }
        saveRecents()
    }

    func orderedPresets() -> [GlassPreset] {
        let baseOrder = Dictionary(uniqueKeysWithValues: presets.enumerated().map { ($1.id, $0) })
        return presets.sorted { lhs, rhs in
            let lhsFavorite = favoritePresetIDs.contains(lhs.id)
            let rhsFavorite = favoritePresetIDs.contains(rhs.id)
            if lhsFavorite != rhsFavorite {
                return lhsFavorite && !rhsFavorite
            }
            return (baseOrder[lhs.id] ?? .max) < (baseOrder[rhs.id] ?? .max)
        }
    }

    private func load() -> [GlassPreset] {
        guard
            let data = defaults.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode([GlassPreset].self, from: data)
        else {
            return GlassPreset.defaults
        }
        return decoded
    }

    private func saveFavorites() {
        let ids = Array(favoritePresetIDs)
        guard let data = try? JSONEncoder().encode(ids) else { return }
        defaults.set(data, forKey: favoritesKey)
    }

    private func loadFavorites() -> Set<UUID> {
        guard
            let data = defaults.data(forKey: favoritesKey),
            let decoded = try? JSONDecoder().decode([UUID].self, from: data)
        else {
            return []
        }
        return Set(decoded)
    }

    private func saveRecents() {
        guard let data = try? JSONEncoder().encode(recentPresetIDs) else { return }
        defaults.set(data, forKey: recentsKey)
    }

    private func loadRecents() -> [UUID] {
        guard
            let data = defaults.data(forKey: recentsKey),
            let decoded = try? JSONDecoder().decode([UUID].self, from: data)
        else {
            return []
        }
        return decoded
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = 18
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}