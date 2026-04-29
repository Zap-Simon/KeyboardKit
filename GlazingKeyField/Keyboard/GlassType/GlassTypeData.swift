import Foundation

// MARK: - Glass type catalogue (ported from GlazierMeasure glass-types-data.ts)

struct GlassTypeDef: Identifiable, Equatable {
    let id: String        // unique slug
    let name: String
    let category: GlassCategory
    let processType: GlassProcessType
    let thicknessMm: Double
    let aliases: [String]

    /// kg / m² (glass density 2500 kg/m³ × thickness in m)
    var areaWeightKgPerM2: Double { thicknessMm / 1000.0 * 2500.0 }
}

enum GlassCategory: String, CaseIterable, Identifiable, Equatable {
    case standard   = "Standard"
    case tint       = "Tint"
    case reflective = "Reflective"
    case laminate   = "Laminate"
    case acoustic   = "Acoustic"
    case obscure    = "Obscure"
    case lowIron    = "Low Iron"
    case mirror     = "Mirror"
    case wired      = "Wired"
    case auto       = "Auto"

    var id: String { rawValue }
}

enum GlassProcessType: String, Equatable {
    case annealed  = "Annealed"
    case toughened = "Toughened"
    case laminate  = "Laminate"
    case mirror    = "Mirror"
}

// MARK: - DGU / IGU

struct SpacerBarDef: Identifiable, Equatable {
    let thicknessMm: Int
    let colour: SpacerColour
    var id: String { "\(thicknessMm)_\(colour.rawValue)" }
    var displayName: String { "\(thicknessMm)mm \(colour.displayTitle)" }

    /// kg / linear metre (based on GlazierMeasure weight table)
    var weightPerLinearMetre: Double {
        switch thicknessMm {
        case 6:  return 0.12
        case 8:  return 0.15
        case 10: return 0.18
        case 12: return 0.22
        case 14: return 0.25
        case 16: return 0.28
        default: return 0.18
        }
    }
}

enum SpacerColour: String, CaseIterable, Identifiable, Equatable {
    case black        = "Black"
    case silver       = "Silver"
    case blackThermal = "Black Thermal"

    var id: String { rawValue }
    var displayTitle: String { rawValue }
}

/// A fully-resolved glass build — either single pane or DGU/IGU
enum GlassBuild: Equatable {
    case single(pane: GlassTypeDef)
    case dgu(outer: GlassTypeDef, spacer: SpacerBarDef, inner: GlassTypeDef)

    var displayName: String {
        switch self {
        case .single(let p):
            return p.name
        case .dgu(let outer, let spacer, let inner):
            return "\(outer.name) / \(spacer.displayName) / \(inner.name)"
        }
    }

    /// Combined nominal thickness in mm (for weight display)
    var totalThicknessMm: Double {
        switch self {
        case .single(let p):
            return p.thicknessMm
        case .dgu(let outer, let spacer, let inner):
            return outer.thicknessMm + Double(spacer.thicknessMm) + inner.thicknessMm
        }
    }

    /// kg/m² of the glass layers only (excludes spacer bar mass)
    var areaWeightKgPerM2: Double {
        switch self {
        case .single(let p):
            return p.areaWeightKgPerM2
        case .dgu(let outer, _, let inner):
            return outer.areaWeightKgPerM2 + inner.areaWeightKgPerM2
        }
    }

    var isDGU: Bool {
        if case .dgu = self { return true }
        return false
    }

    var outerPane: GlassTypeDef? {
        switch self {
        case .single(let p): return p
        case .dgu(let outer, _, _): return outer
        }
    }
}

// MARK: - Catalogue

enum GlassTypeCatalogue {

    static let allTypes: [GlassTypeDef] = [
        // Standard
        .make("3mm Clear Annealed",   3,     .standard,   .annealed),
        .make("4mm Clear Annealed",   4,     .standard,   .annealed),
        .make("4mm Clear Toughened",  4,     .standard,   .toughened),
        .make("5mm Clear Annealed",   5,     .standard,   .annealed),
        .make("5mm Clear Toughened",  5,     .standard,   .toughened),
        .make("6mm Clear Annealed",   6,     .standard,   .annealed),
        .make("6mm Clear Toughened",  6,     .standard,   .toughened),
        .make("8mm Clear Annealed",   8,     .standard,   .annealed),
        .make("8mm Clear Toughened",  8,     .standard,   .toughened),
        .make("10mm Clear Annealed",  10,    .standard,   .annealed),
        .make("10mm Clear Toughened", 10,    .standard,   .toughened),
        .make("12mm Clear Annealed",  12,    .standard,   .annealed),
        .make("12mm Clear Toughened", 12,    .standard,   .toughened),
        .make("15mm Clear Annealed",  15,    .standard,   .annealed),
        .make("15mm Clear Toughened", 15,    .standard,   .toughened),
        // Tint – Bronze
        .make("4mm Bronze Annealed",  4,     .tint,       .annealed),
        .make("4mm Bronze Toughened", 4,     .tint,       .toughened),
        .make("5mm Bronze Annealed",  5,     .tint,       .annealed),
        .make("5mm Bronze Toughened", 5,     .tint,       .toughened),
        // Tint – Green
        .make("5mm Green Annealed",   5,     .tint,       .annealed),
        .make("5mm Green Toughened",  5,     .tint,       .toughened),
        .make("6mm Green Annealed",   6,     .tint,       .annealed),
        .make("6mm Green Toughened",  6,     .tint,       .toughened),
        // Tint – Grey
        .make("4mm Grey Annealed",    4,     .tint,       .annealed),
        .make("4mm Grey Toughened",   4,     .tint,       .toughened),
        .make("5mm Grey Annealed",    5,     .tint,       .annealed),
        .make("5mm Grey Toughened",   5,     .tint,       .toughened),
        .make("6mm Grey Annealed",    6,     .tint,       .annealed),
        .make("6mm Grey Toughened",   6,     .tint,       .toughened),
        .make("10mm Grey Annealed",   10,    .tint,       .annealed),
        .make("10mm Grey Toughened",  10,    .tint,       .toughened),
        .make("12mm Grey Annealed",   12,    .tint,       .annealed),
        .make("12mm Grey Toughened",  12,    .tint,       .toughened),
        .make("5mm Supergrey Annealed",   5, .tint,       .annealed),
        .make("5mm Supergrey Toughened",  5, .tint,       .toughened),
        // Reflective
        .make("6mm Stopsol Clear Annealed",  6, .reflective, .annealed),
        .make("6mm Stopsol Clear Toughened", 6, .reflective, .toughened),
        .make("6mm Stopsol Grey Annealed",   6, .reflective, .annealed),
        .make("6mm Stopsol Grey Toughened",  6, .reflective, .toughened),
        // Laminate
        .make("6.38mm Clear Laminate",        6.38, .laminate,  .laminate),
        .make("8.38mm Clear Laminate",        8.38, .laminate,  .laminate),
        .make("10.38mm Clear Laminate",      10.38, .laminate,  .laminate),
        .make("12.38mm Clear Laminate",      12.38, .laminate,  .laminate),
        .make("6.38mm Grey Laminate",         6.38, .laminate,  .laminate),
        .make("10.38mm Grey Laminate",       10.38, .laminate,  .laminate),
        .make("6.38mm Translucent Laminate",  6.38, .laminate,  .laminate),
        // Acoustic
        .make("6.76mm Acoustic Laminate",    6.76,  .acoustic,  .laminate),
        .make("8.76mm Acoustic Laminate",    8.76,  .acoustic,  .laminate),
        .make("10.76mm Acoustic Laminate",  10.76,  .acoustic,  .laminate),
        .make("12.76mm Acoustic Laminate",  12.76,  .acoustic,  .laminate),
        // Obscure
        .make("4mm Cathedral Annealed",   4, .obscure, .annealed),
        .make("4mm Cathedral Toughened",  4, .obscure, .toughened),
        .make("5mm Cathedral Annealed",   5, .obscure, .annealed),
        .make("5mm Cathedral Toughened",  5, .obscure, .toughened),
        .make("5mm Mistlite Annealed",    5, .obscure, .annealed),
        .make("5mm Mistlite Toughened",   5, .obscure, .toughened),
        .make("4mm Stippolite Annealed",  4, .obscure, .annealed),
        .make("4mm Stippolite Toughened", 4, .obscure, .toughened),
        .make("5mm Stippolite Annealed",  5, .obscure, .annealed),
        .make("5mm Stippolite Toughened", 5, .obscure, .toughened),
        .make("5mm Arctic Annealed",      5, .obscure, .annealed),
        .make("5mm Arctic Toughened",     5, .obscure, .toughened),
        .make("5mm Seadrift Annealed",    5, .obscure, .annealed, aliases: ["5mm Cotswold Annealed"]),
        .make("5mm Seadrift Toughened",   5, .obscure, .toughened, aliases: ["5mm Cotswold Toughened"]),
        .make("4mm Etchlite Annealed",    4, .obscure, .annealed),
        .make("4mm Etchlite Toughened",   4, .obscure, .toughened),
        .make("5mm Etchlite Annealed",    5, .obscure, .annealed),
        .make("5mm Etchlite Toughened",   5, .obscure, .toughened),
        .make("6mm Etchlite Annealed",    6, .obscure, .annealed),
        .make("6mm Etchlite Toughened",   6, .obscure, .toughened),
        .make("10mm Etchlite Annealed",   10, .obscure, .annealed),
        .make("10mm Etchlite Toughened",  10, .obscure, .toughened),
        .make("5mm Broad Reeded Annealed",   5, .obscure, .annealed),
        .make("5mm Broad Reeded Toughened",  5, .obscure, .toughened),
        .make("5mm Narrow Reeded Annealed",  5, .obscure, .annealed),
        .make("5mm Narrow Reeded Toughened", 5, .obscure, .toughened),
        .make("10mm Narrow Reeded Annealed",  10, .obscure, .annealed),
        .make("10mm Narrow Reeded Toughened", 10, .obscure, .toughened),
        // Low Iron
        .make("4mm Low Iron Annealed",    4,  .lowIron, .annealed),
        .make("4mm Low Iron Toughened",   4,  .lowIron, .toughened),
        .make("5mm Low Iron Annealed",    5,  .lowIron, .annealed),
        .make("5mm Low Iron Toughened",   5,  .lowIron, .toughened),
        .make("6mm Low Iron Annealed",    6,  .lowIron, .annealed),
        .make("6mm Low Iron Toughened",   6,  .lowIron, .toughened),
        .make("10mm Low Iron Annealed",   10, .lowIron, .annealed),
        .make("10mm Low Iron Toughened",  10, .lowIron, .toughened),
        // Wired
        .make("6mm Wired Cast Annealed",     6, .wired,  .annealed),
        .make("6mm Wired Polished Annealed", 6, .wired,  .annealed),
        // Mirror
        .make("4mm Mirror",         4, .mirror, .mirror),
        .make("5mm Mirror",         5, .mirror, .mirror),
        .make("6mm Mirror",         6, .mirror, .mirror),
        .make("5mm Bronze Mirror",  5, .mirror, .mirror),
        .make("4mm Vinylback Mirror", 4, .mirror, .mirror),
        .make("6mm Vinylback Mirror", 6, .mirror, .mirror),
    ]

    static let spacerBars: [SpacerBarDef] = {
        var bars: [SpacerBarDef] = []
        for mm in [6, 8, 10, 12, 14, 16] {
            bars.append(SpacerBarDef(thicknessMm: mm, colour: .black))
            bars.append(SpacerBarDef(thicknessMm: mm, colour: .silver))
            if mm >= 10 {
                bars.append(SpacerBarDef(thicknessMm: mm, colour: .blackThermal))
            }
        }
        return bars
    }()

    // MARK: Search

    /// Returns glass types whose name or aliases contain `query` (case-insensitive).
    /// Empty query returns all types ordered by category then name.
    static func search(_ query: String) -> [GlassTypeDef] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return allTypes }
        return allTypes.filter { type in
            type.name.lowercased().contains(q) ||
            type.aliases.contains(where: { $0.lowercased().contains(q) }) ||
            type.category.rawValue.lowercased().contains(q)
        }
    }

    static func spacerSearch(_ query: String) -> [SpacerBarDef] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return spacerBars }
        return spacerBars.filter { $0.displayName.lowercased().contains(q) }
    }
}

// MARK: - Factory helper

private extension GlassTypeDef {
    static func make(
        _ name: String,
        _ thicknessMm: Double,
        _ category: GlassCategory,
        _ process: GlassProcessType,
        aliases: [String] = []
    ) -> GlassTypeDef {
        GlassTypeDef(
            id: name.lowercased().replacingOccurrences(of: " ", with: "_"),
            name: name,
            category: category,
            processType: process,
            thicknessMm: thicknessMm,
            aliases: aliases
        )
    }
}
