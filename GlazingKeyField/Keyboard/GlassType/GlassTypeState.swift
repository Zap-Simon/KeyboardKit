import Foundation
import Combine

// MARK: - GlassTypeState

/// Drives the Type tab builder. Three-step flow:
///   1. Select / search a pane type  (outer pane, always required)
///   2. If DGU: select spacer bar
///   3. If DGU: select inner pane  (defaults to outer pane)
final class GlassTypeState: ObservableObject {

    // ── Search state ───────────────────────────────────────────────────────
    @Published var searchQuery: String = ""
    @Published var suggestions: [GlassTypeDef] = []

    // ── Build state ────────────────────────────────────────────────────────
    @Published var buildMode: BuildMode = .single
    @Published var outerPane: GlassTypeDef? = nil
    @Published var spacerBar: SpacerBarDef? = nil
    @Published var innerPane: GlassTypeDef? = nil     // nil = same as outer

    // ── Resolved build (nil until outer is set) ────────────────────────────
    var confirmedBuild: GlassBuild? {
        guard let outer = outerPane else { return nil }
        switch buildMode {
        case .single:
            return .single(pane: outer)
        case .dgu:
            let spacer = spacerBar ?? GlassTypeCatalogue.spacerBars.first(where: {
                $0.thicknessMm == 10 && $0.colour == .black
            }) ?? GlassTypeCatalogue.spacerBars[0]
            let inner = innerPane ?? outer
            return .dgu(outer: outer, spacer: spacer, inner: inner)
        }
    }

    /// kg / m² for weight pre-population
    var areaWeightKgPerM2: Double? { confirmedBuild?.areaWeightKgPerM2 }

    // ── Step enum ──────────────────────────────────────────────────────────
    enum BuildMode: Equatable {
        case single
        case dgu
    }

    // ── Keyboard search integration ────────────────────────────────────────
    /// Call whenever the user types a character via the numpad letter keys or
    /// a KeyboardKit suggestion is accepted.
    func appendToSearch(_ char: String) {
        searchQuery.append(char)
        updateSuggestions()
    }

    func deleteFromSearch() {
        guard !searchQuery.isEmpty else { return }
        searchQuery.removeLast()
        updateSuggestions()
    }

    func clearSearch() {
        searchQuery = ""
        suggestions = []
    }

    func selectSuggestion(_ type: GlassTypeDef) {
        if outerPane == nil {
            outerPane = type
            if buildMode == .dgu, spacerBar == nil {
                spacerBar = GlassTypeCatalogue.spacerBars.first(where: {
                    $0.thicknessMm == 10 && $0.colour == .black
                })
            }
        } else if buildMode == .dgu, innerPane == nil {
            innerPane = type
        }
        clearSearch()
    }

    func reset() {
        searchQuery = ""
        suggestions = []
        outerPane = nil
        spacerBar = nil
        innerPane = nil
    }

    func setBuildMode(_ mode: BuildMode) {
        buildMode = mode
        if mode == .single {
            spacerBar = nil
            innerPane = nil
        }
    }

    // ── Predictive suggestions ─────────────────────────────────────────────
    /// Returns suggestion strings suitable for a KeyboardKit autocomplete bar.
    var keyboardSuggestions: [String] {
        suggestions.prefix(3).map { $0.name }
    }

    private func updateSuggestions() {
        suggestions = GlassTypeCatalogue.search(searchQuery)
    }
}
