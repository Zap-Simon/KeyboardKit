# GlazingKey Field

> Glass trade keyboard for iOS — sight, tight, cut size and weight, directly inside any app.

Built on [KeyboardKit](https://github.com/KeyboardKit/KeyboardKit) 10.x (binary XCFramework, local package).  
Current version: **2.4.1** (build 38) · Deployment target: **iOS 17.6+**

---

## File Tree

```
KeyboardKit/                          ← repo root (KeyboardKit XCFramework package)
│
├── GlazingKeyField/                  ← Xcode project root
│   │
│   ├── GlazingKeyField.xcodeproj/   ← Xcode project (2 targets: app + extension)
│   │   └── xcshareddata/xcschemes/
│   │       ├── GlazingKeyField.xcscheme   ← main app build/archive scheme
│   │       └── Keyboard.xcscheme          ← keyboard extension scheme
│   │
│   ├── GlazingKeyField/             ← App target source
│   │   ├── DemoApp.swift            ← @main App struct (GlazingKeyFieldApp)
│   │   ├── HomeScreen.swift         ← App UI: hero card, workflow guide, test area
│   │   ├── KeyboardApp+Demo.swift   ← KeyboardApp.glazingKeyField definition
│   │   ├── Assets/Assets.xcassets/  ← AppIcon, AccentColor, Icon
│   │   ├── Dictation/
│   │   │   └── StandardSpeechRecognizer.swift   ← AVFoundation speech stub
│   │   ├── License/
│   │   │   └── KeyboardKit.license  ← Pro licence file (unlocks full KeyboardKit)
│   │   ├── Localization/
│   │   │   └── Localizable.xcstrings
│   │   └── Settings.bundle/         ← iOS Settings app bundle (debug toggle)
│   │
│   └── Keyboard/                    ← Keyboard extension target source
│       ├── KeyboardViewController.swift   ← UIKit entry point (KeyboardInputViewController)
│       ├── DemoKeyboardView.swift         ← All SwiftUI keyboard UI
│       ├── DemoKeyboardMenu.swift         ← Business logic: calculations, presets, state
│       ├── DemoToolbar.swift              ← Settings panel UI (preset editor)
│       └── Assets/
│           └── fuse.wav             ← Haptic/audio feedback sound
│
├── Dependencies/KeyboardKitDependencies/  ← Local Swift package target (wires LicenseKit)
├── Package.swift                          ← Declares KeyboardKit + LicenseKit products
├── Package.resolved                       ← Pinned: KeyboardKit 10.4.1, LicenseKit 2.1.3
├── codemagic.yaml                         ← CI build pipeline (Codemagic)
├── bump / scripts/bump_version.sh         ← Version bump helper
└── Docs/Localization.md
```

---

## Architecture

### Entry points

| File | Role |
|---|---|
| `GlazingKeyFieldApp` | SwiftUI `App` — wraps `HomeScreen` inside `KeyboardAppView(for: .glazingKeyField)` which boots KeyboardKit |
| `KeyboardApp.glazingKeyField` | Declares app name, deep link scheme, locale list, autocomplete config |
| `KeyboardViewController` | Subclass of `KeyboardInputViewController` — mounts the SwiftUI view tree into the extension |
| `KeyboardRootView` | Root SwiftUI view handed to `setupKeyboardView {}` |

### Keyboard UI layers (bottom → top)

```
KeyboardRootView  (.frame maxWidth/maxHeight .infinity, aligned .bottom)
└── keyboardShell  (.frame height: 408, clipped rounded top corners)
    ├── KeyboardMaterialShellView          ← always-visible background
    │   iOS 26+ → .ultraThinMaterial      ← Liquid Glass
    │   iOS 17–18 → solid grey (exact system match)
    │   + 0.5pt separator line at top edge
    └── [if isContentVisible]
        ├── SettingsPanelView              ← shown when state.showSettings == true
        └── keyboardContent (VStack)
            ├── ModeSelectorView           ← animated pill tab: Glazing / Weight
            ├── GlassTypeSelectorView      ← horizontal preset scroll (Glazing mode)
            │   or WeightSpecSelectorView  ← horizontal spec scroll (Weight mode)
            ├── MeasurementDisplayView     ← 2 or 3 input cards with live result
            └── NumpadView                 ← digit keys + operators + insert/delete
```

`isContentVisible` is `false` only during the very first launch (before `viewDidAppear`) to prevent the grey shell flashing over the host app background while the extension is sizing. After first appearance it stays `true` permanently.

---

## Business Logic

All domain code lives in `DemoKeyboardMenu.swift`:

| Type | What it does |
|---|---|
| `ExpressionParser` | Evaluates simple `+` / `-` integer expressions (e.g. `890+5`) |
| `GlassPreset` | Named formula (adjustment mm) — stored/ordered via `PresetsStore` |
| `GlazingCalculator` | Computes cut size from sight+tight+formula; picks source dimension by sign of adjustment |
| `GlazingResult` | Value type; formats the multi-line glazing record for insertion |
| `GlassWeightSpec` | Named build-up with areal density (kg/m²) |
| `GlassWeightCalculator` | Area × density → weight, plus handling recommendation |
| `GlassWeightResult` | Value type; formats the single-line weight record for insertion |
| `PresetsStore` | `ObservableObject` — manages custom presets, favourites, recents via `UserDefaults` |
| `KeyboardState` | `ObservableObject` — all live input field values, active field, mode, showSettings |

---

## Calculation Logic

### Glazing cut size formula

```
cut = source_measurement + preset.adjustment
```

- `source` is either **Sight** or **Tight**, set per-preset
- The opposite measurement is **optional** — entering it unlocks extra diagnostics (clearance, S↔T diff)
- `adjustment` can be positive or negative; `ExpressionParser` supports simple `+`/`-` expressions in any field (e.g. `890+5`)

**Built-in presets:**

| Preset | Source | Adjustment | Meaning |
|---|---|---|---|
| Double Glazing | Sight | +24 | Cut = sight + 24mm (rebate covers 12mm each side) |
| Single Aluminium | Tight | −12 | Cut = tight − 12mm (6mm clearance each side) |
| Single Timber | Tight | −2 | Cut = tight − 2mm (1mm clearance each side) |

Custom presets are stored per-user in `UserDefaults` and can use any source and any adjustment value.

---

### Clearance (gap between glass and frame)

Clearance is calculated from the **tight** measurement when available:

```
clearance_per_side = (tight − cut) / 2
```

A positive value means the glass fits with a gap. A negative value means the glass is **physically larger than the opening** — it won't fit.

Overlap into the rebate is calculated from the **sight** measurement:

```
overlap_per_side = (cut − sight) / 2
```

**Clearance status rules** (shown as a badge on the clearance row):

| Condition | Status | Badge colour |
|---|---|---|
| Any clearance value < 0 | Oversize! — won't fit | 🔴 Red |
| Both H and W within 2mm of each other | Consistent | 🟢 Green |
| H/W difference 2–5mm | Check measurements | 🟠 Orange |
| H/W difference ≥ 5mm | Re-measure! | 🔴 Red |
| Only one dimension available | No badge | — |

When oversize: row background turns red, label changes to **"Oversize!"**, and the printed record includes a `⚠ Glass oversize: …` warning line.

---

### Sight–Tight difference row (S↔T)

Shows below the clearance row. Compares the rebate depth implied by each measurement:

```
diff_height = tight_height − sight_height
diff_width  = tight_width  − sight_width
```

A healthy result should show equal (or near-equal) differences in both dimensions, meaning the rebate depth is consistent all round.

**Display rules:**

| Inputs entered | Row visible? | Value shown | Badge |
|---|---|---|---|
| Neither sight nor tight | Hidden | — | — |
| Only sight entered | ✅ Visible | "Measure tight opening" | 🔍 Investigate / Orange |
| Only tight entered | ✅ Visible | "Measure sight opening" | 🔍 Investigate / Orange |
| Both entered, diff = 0 on both | ✅ Visible | H 0mm  W 0mm | ⚠ Sight = Tight? / Orange |
| Both entered, \|H diff − W diff\| ≤ 3mm | ✅ Visible | H Xmm  W Xmm | ✓ Consistent / Green |
| Both entered, \|H diff − W diff\| > 3mm | ✅ Visible | H Xmm  W Xmm | ⚠ Check / Orange |

> **Why "Investigate" when one is missing?**  
> If only sight was measured, the user has everything needed for a sight-based formula but lacks the tight measurement to calculate clearance or verify the rebate. The badge prompts them to go measure the other dimension on site.
>
> **Why "Sight = Tight?" at zero?**  
> If tight == sight, either the frame has zero rebate depth (unusual) or one measurement was entered in the wrong field. Worth verifying on site before cutting.

---

### Weight calculation

```
area_m2  = (cut_width_mm / 1000) × (cut_height_mm / 1000)
weight_kg = area_m2 × areal_density_kg_per_m2
```

**Built-in glass specs (areal density):**

| Spec | kg/m² |
|---|---|
| Single 4mm | 10 |
| Single 6mm | 15 |
| Single 10mm | 25 |
| DGU 4-16-4 | 20 |
| Laminate 6.38mm | 16 |

**Handling recommendation thresholds:**

| Weight | Recommendation |
|---|---|
| < 25 kg | Single person lift |
| 25–49 kg | Two person lift |
| 50–89 kg | Team / manual aid |
| ≥ 90 kg | Mechanical lift recommended |

Weight mode uses the confirmed glass type from the **Glass Type** panel and the cut dimensions from Glazing mode. If either is not yet set, a prompt card is shown instead of the result.

---

## What KeyboardKit Provides

This keyboard uses KeyboardKit as a **host framework** — it handles the UIKit/SwiftUI bridge, extension lifecycle, and licence management. The glazing UI is entirely custom. Here's what KeyboardKit makes available that could be adopted:

### Currently used
- `KeyboardInputViewController` — base class replacing `UIInputViewController`
- `KeyboardAppView` — boots the licence and sets up the app side
- `KeyboardApp` — configuration object (name, locales, deep links, autocomplete config)
- `setupKeyboardView {}` — mounts a custom SwiftUI view into the extension

### Available but not yet adopted

| Feature | KeyboardKit API | How to add |
|---|---|---|
| **Autocomplete** | `AutocompleteService`, `AutocompleteContext` | Wire a service in `KeyboardApp.glazingKeyField` (`autocomplete:`) and show `AutocompleteToolbar` above the numpad |
| **AI next-word prediction** | `.claude(apiKey:)` or `.openAI(apiKey:)` in `autocomplete:` | Uncomment the `nextWordPredictionRequest` line in `KeyboardApp+Demo.swift` |
| **Haptic feedback** | `HapticFeedback.prepare()` / `.trigger()` | Call on key tap inside `NumpadView` button actions |
| **Audio feedback** | `AudioFeedback.input.trigger()` | Same tap handlers — complements `fuse.wav` |
| **Dictation** | `DictationContext`, `KeyboardDictationService` | `StandardSpeechRecognizer.swift` is already stubbed; wire to a dictation button |
| **App Group sync** | `appGroupId:` in `KeyboardApp.init` | Share `PresetsStore` data between app and extension via a shared container |
| **Full Access detection** | `controller.hasFullAccess` | Show a prompt in `HomeScreen` or settings when Full Access is off |
| **Locale switching** | `KeyboardContext.locale`, `LocaleContextMenu` | Add a locale flag button to `NumpadView` toolbar row |
| **External keyboard** | `KeyboardContext.isKeyboardFloating` | Adjust `keyboardHeight` when floating |
| **Theme engine** | `KeyboardTheme`, `KeyboardStyle` | Replace the hardcoded colour constants with a theme definition |

---

## Versioning & CI

```bash
./bump              # increment build number only
./bump patch        # e.g. 2.4.1 → 2.4.2
./bump minor        # e.g. 2.4.1 → 2.5.0
./bump major        # e.g. 2.4.1 → 3.0.0
./bump 2.5.0 42     # set exact version + build
```

`bump` edits `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.pbxproj` directly.  
Codemagic (`codemagic.yaml`) sets `CFBundleVersion` from `CM_BUILD_NUMBER` at archive time.

---

## KeyboardKit Getting-Started Compliance Audit

Reference: [docs.keyboardkit.com/getting-started](https://docs.keyboardkit.com/documentation/keyboardkit/getting-started-article/)

| Step | What the docs say | What we do | Status |
|---|---|---|---|
| **1. Add package** | Binary XCFramework, app target only | Local `Package.swift` at repo root, linked to app target only | ✅ |
| **2. KeyboardApp** | Define in a shared file, add to both targets | `KeyboardApp+Demo.swift` added to both app + keyboard | ✅ |
| **3. Extension setup** | Override `viewWillSetupKeyboardKit()`, call `setupKeyboardKit(for:completion:)` | `viewWillSetupKeyboardKit()` + `setupKeyboardKit(for:completion:)` | ✅ Fixed |
| **4. Custom view** | Override `viewWillSetupKeyboardView()`, call `setupKeyboardView { [weak self] }` | Done correctly, with `[weak self]` guard | ✅ |
| **5. Main app** | Use `KeyboardAppView(for:)` as root | `GlazingKeyFieldApp` wraps `HomeScreen` in `KeyboardAppView(for: .glazingKeyField)` | ✅ |
| **6. State & services** | Customise in `setupKeyboardKit` completion block | Not customised (not needed for fully custom view) | ✅ |

### ✅ `setupKeyboardKit(for:completion:)` — migrated

`setup(for:)` (deprecated) has been replaced. `viewWillSetupKeyboardKit()` now calls `setupKeyboardKit(for:completion:)`, and `renderState.isContentVisible = false` is set before `super.viewDidLoad()` so the view is hidden before the framework mounts it:

```swift
override func viewDidLoad() {
    renderState.isContentVisible = false  // set before super mounts the view
    view.backgroundColor = .clear
    view.isOpaque = false
    super.viewDidLoad()
    clearHostBackgrounds()
}

override func viewWillSetupKeyboardKit() {
    setupKeyboardKit(for: .glazingKeyField) { _ in }
}
```

### ✅ `textWillChange` / `textDidChange` — stubs removed

The empty overrides that suppressed KeyboardKit's text tracking have been removed. The default implementations now run, keeping `KeyboardContext` up to date with cursor position and text content. This is a prerequisite for autocomplete if you add it later.

### ℹ️ No `appGroupId`

`KeyboardApp.glazingKeyField` has no `appGroupId`. This means:
- The app and keyboard extension each have their own isolated `UserDefaults`
- `PresetsStore` data created in the keyboard is **not** visible in the main app, and vice versa
- If you want the app's HomeScreen to display or edit presets, you must add an App Group

To enable: create an App Group in both target's Capabilities (`group.com.glazingkey.field`), add `appGroupId: "group.com.glazingkey.field"` to `KeyboardApp.glazingKeyField`, and update `PresetsStore` to use `UserDefaults(suiteName: "group.com.glazingkey.field")`.

### ✅ `needsInputModeSwitchKey` — environment object

`needsInputModeSwitch` is no longer passed as a constructor argument through `KeyboardRootView` → `NumpadView` → `KeypadButtonView`. Both `NumpadView` and `KeypadButtonView` now read it directly from the environment:

```swift
@EnvironmentObject private var keyboardContext: KeyboardContext
// keyboardContext.needsInputModeSwitchKey
```

KeyboardKit injects `KeyboardContext` into the SwiftUI environment automatically via `setupKeyboardView`, so it's available anywhere in the view tree.

---

## Settings.bundle — What it is and current state

The `Settings.bundle` folder causes GlazingKey Field to appear as an entry inside the **iOS Settings app** (Settings → GlazingKey Field). It can expose toggle switches, text fields, and sliders that the user can configure without opening the app.

**Right now it is empty.** `Root.plist` has no `PreferenceSpecifiers` array defined, so the Settings entry shows a blank page. This is not a bug — it's a placeholder. The bundle is bundled with the app because it was scaffolded in but never filled out.

### The debug toggle does NOT use Settings.bundle

The debug mode flag (`glazing_keyboard_debug_mode_v1`) is stored in `UserDefaults.standard` and toggled from **inside the keyboard's own settings panel** (the ⚙ button). The `@AppStorage` key is shared between the keyboard extension (`DemoKeyboardView.swift`) and the settings panel (`DemoToolbar.swift`) so both read the same value.

### What you could put in Settings.bundle

| Preference type | Example use |
|---|---|
| Toggle switch | "Show debug overlay" — expose `glazing_keyboard_debug_mode_v1` key here instead of (or as well as) the in-keyboard toggle |
| Toggle switch | "Play key sounds" |
| Radio group | Default glass formula on fresh install |
| Text field | User's company name to prepend to records |
| Static group | App version, build number (read-only display) |

To add a toggle, replace `Root.plist` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PreferenceSpecifiers</key>
    <array>
        <dict>
            <key>Type</key>        <string>PSToggleSwitchSpecifier</string>
            <key>Title</key>       <string>Debug Overlay</string>
            <key>Key</key>         <string>glazing_keyboard_debug_mode_v1</string>
            <key>DefaultValue</key><false/>
        </dict>
    </array>
    <key>StringsTable</key>
    <string>Root</string>
</dict>
</plist>
```

> **Note:** Settings.bundle values are only shared with the keyboard extension if you use an **App Group** container (`UserDefaults(suiteName:)`). Currently both the app and extension use `UserDefaults.standard` — which works on device but would not sync across targets if you later add an App Group.

---

## Debug Mode

When enabled, a small badge appears top-left of the keyboard showing the root view size and the last 4 layout-pass events. Useful for diagnosing sizing regressions.

```
DBG root:390x408
root 0x408
root 390x844
root 390x408
```

The first three entries on cold launch are normal KeyboardKit setup passes (the extension view is resized as KeyboardKit replaces the input view). Subsequent appearances should show only a single stable `390x408` line — confirming the `isContentVisible` guard is working correctly.
