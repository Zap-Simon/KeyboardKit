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

struct GlazingResult {
    enum CalculationSource {
        case sight
        case tight
    }

    let sightWidth: Int
    let sightHeight: Int
    let tightWidth: Int
    let tightHeight: Int
    let cutWidth: Int
    let cutHeight: Int
    let adjustment: Int
    let presetName: String
    let calculationSource: CalculationSource

    var formattedRecord: String {
        let sightLabel = calculationSource == .sight ? "Sight*" : "Sight"
        let tightLabel = calculationSource == .tight ? "Tight*" : "Tight"
        return [
            "1@ \(cutSizeOnly)",
            "",
            "\(sightLabel): \(sightSize)",
            "\(tightLabel): \(tightSize)",
            "Formula: \(formulaAdjustment)"
        ]
        .joined(separator: "\n")
    }

    var cutSizeOnly: String {
        "\(cutHeight)x\(cutWidth)"
    }

    var sightSize: String {
        "\(sightHeight)x\(sightWidth)"
    }

    var tightSize: String {
        "\(tightHeight)x\(tightWidth)"
    }

    private var formulaAdjustment: String {
        adjustment > 0 ? "(+\(adjustment))" : "(\(adjustment))"
    }
}

struct GlazingCalculator {

    static func calculate(
        sightWidth: Int,
        sightHeight: Int,
        tightWidth: Int,
        tightHeight: Int,
        preset: GlassPreset
    ) -> GlazingResult {
        let adjustment = preset.adjustment
        let source: GlazingResult.CalculationSource = adjustment > 0 ? .sight : .tight
        let baseWidth = source == .sight ? sightWidth : tightWidth
        let baseHeight = source == .sight ? sightHeight : tightHeight

        return GlazingResult(
            sightWidth: sightWidth,
            sightHeight: sightHeight,
            tightWidth: tightWidth,
            tightHeight: tightHeight,
            cutWidth: baseWidth + adjustment,
            cutHeight: baseHeight + adjustment,
            adjustment: adjustment,
            presetName: preset.name,
            calculationSource: source
        )
    }

    static func calculate(
        sightWidthExpr: String,
        sightHeightExpr: String,
        tightWidthExpr: String,
        tightHeightExpr: String,
        preset: GlassPreset
    ) -> GlazingResult? {
        guard
            let sightWidth = ExpressionParser.evaluate(sightWidthExpr),
            let sightHeight = ExpressionParser.evaluate(sightHeightExpr),
            let tightWidth = ExpressionParser.evaluate(tightWidthExpr),
            let tightHeight = ExpressionParser.evaluate(tightHeightExpr)
        else {
            return nil
        }

        return calculate(
            sightWidth: sightWidth,
            sightHeight: sightHeight,
            tightWidth: tightWidth,
            tightHeight: tightHeight,
            preset: preset
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

    init(id: UUID = UUID(), name: String, adjustment: Int) {
        self.id = id
        self.name = name
        self.adjustment = adjustment
    }

    var adjustmentLabel: String {
        adjustment > 0 ? "+\(adjustment)" : "\(adjustment)"
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case adjustment
        case deductions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)

        if let adjustment = try container.decodeIfPresent(Int.self, forKey: .adjustment) {
            self.adjustment = adjustment
            return
        }

        let oldDeductions = try container.decodeIfPresent([String: Int].self, forKey: .deductions) ?? [:]
        adjustment = oldDeductions["uPVC"] ?? oldDeductions.values.first ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(adjustment, forKey: .adjustment)
    }
}

extension GlassPreset {
    static let defaults: [GlassPreset] = [
        GlassPreset(name: "Double Glazing", adjustment: 24),
        GlassPreset(name: "Single Aluminium", adjustment: -12),
        GlassPreset(name: "Single Timber", adjustment: -2)
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