import SwiftUI

struct HomeScreen: View {

    @Environment(\.colorScheme) private var colorScheme

    @State private var quoteText = ""
    @State private var outputIndex:   Int    = 0
    @State private var outputOpacity: Double = 1
    @State private var appeared      = false
    @State private var outputBounce  = false
    @State private var outputTab     = 0

    private let cycleExamples: [(badge: String, record: String)] = [
        ("GLAZING", "1@ 1224x924\n\nSight*: 1200x900\nTight: 1198x896\nFormula: (+24)"),
        ("QUICK",   "1@ 850x600"),
        ("WEIGHT",  "Glass: DGU 4-16-4\nSize: 1224x924 | 22.6 kg\nHandling: Single person lift")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroCard
                        .cardEntrance(delay: 0.05, appeared: appeared)
                    setupCard
                        .cardEntrance(delay: 0.13, appeared: appeared)
                    fullAccessCard
                        .cardEntrance(delay: 0.19, appeared: appeared)
                    sampleOutputCard
                        .cardEntrance(delay: 0.25, appeared: appeared)
                    formulaInfoCard
                        .cardEntrance(delay: 0.31, appeared: appeared)
                    workflowCard
                        .cardEntrance(delay: 0.37, appeared: appeared)
                    testAreaCard
                        .cardEntrance(delay: 0.44, appeared: appeared)
                }
                .padding(16)
            }
            .background(MaterialScreenBackground())
            .navigationTitle("GlazingKey Field")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                appeared = true
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
                guard !Task.isCancelled else { break }
                await cycleOutput()
            }
        }
    }

    @MainActor
    private func cycleOutput() async {
        withAnimation(.easeOut(duration: 0.2)) { outputOpacity = 0 }
        try? await Task.sleep(nanoseconds: 270_000_000)
        outputIndex = (outputIndex + 1) % cycleExamples.count
        withAnimation(.easeIn(duration: 0.25)) { outputOpacity = 1 }
    }

    @MainActor
    private func tapOutput() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) { outputBounce = true }
        Task {
            try? await Task.sleep(nanoseconds: 160_000_000)
            outputBounce = false
            await cycleOutput()
        }
    }

    private func openKeyboardSettings() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let preferred = URL(string: "App-Prefs:root=General&path=Keyboard/KEYBOARDS")
        let fallback  = URL(string: UIApplication.openSettingsURLString)
        if let url = preferred {
            UIApplication.shared.open(url) { success in
                guard !success, let fb = fallback else { return }
                UIApplication.shared.open(fb)
            }
        } else if let url = fallback {
            UIApplication.shared.open(url)
        }
    }
}

private extension HomeScreen {

    var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Glass trade keyboard")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(ScreenTheme.accent)

            Text("Measure once.\nInsert instantly.")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.18, green: 0.52, blue: 1.0),
                                 Color(red: 0.0,  green: 0.80, blue: 0.90)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .lineSpacing(3)

            Button(action: tapOutput) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(cycleExamples[outputIndex].badge)
                            .font(.system(size: 9, weight: .black))
                            .tracking(1.4)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                        Spacer()
                        HStack(spacing: 5) {
                            ForEach(cycleExamples.indices, id: \.self) { i in
                                Circle()
                                    .fill(i == outputIndex
                                          ? Color.accentColor
                                          : Color.secondary.opacity(0.3))
                                    .frame(width: 5, height: 5)
                                    .animation(.spring(response: 0.3), value: outputIndex)
                            }
                        }
                    }
                    Text(cycleExamples[outputIndex].record)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ScreenTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .opacity(outputOpacity)
                }
                .padding(14)
                .background {
                    MaterialScreenInsetBackground(cornerRadius: 14, tint: ScreenTheme.panelTint(for: colorScheme))
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .scaleEffect(outputBounce ? 0.97 : 1.0)

            HStack(spacing: 8) {
                statPill(icon: "bolt.fill",  label: "Instant calc")
                statPill(icon: "lock.fill",  label: "Private")
                statPill(icon: "doc.text",   label: "Any app")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            MaterialScreenCardBackground(cornerRadius: 20, tint: ScreenTheme.cardTint(for: colorScheme), shadowOpacity: 0.14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    var fullAccessCard: some View {
        VStack(alignment: .leading, spacing: 16) {

            // Header
            Text("Full Access")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(ScreenTheme.accent)

            // Hero row
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(ScreenTheme.accent.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(ScreenTheme.accent)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unlock the full keyboard")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(ScreenTheme.ink)
                    Text("Full Access enables clipboard history and saved login credentials — stored securely on-device, never shared.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(ScreenTheme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Step-by-step path
            VStack(alignment: .leading, spacing: 0) {
                fullAccessStep(number: 1, text: "Settings")
                stepArrow
                fullAccessStep(number: 2, text: "General")
                stepArrow
                fullAccessStep(number: 3, text: "Keyboard")
                stepArrow
                fullAccessStep(number: 4, text: "Keyboards")
                stepArrow
                fullAccessStep(number: 5, text: "Glazing Key")
                stepArrow
                fullAccessStep(number: 6, text: "Allow Full Access  \u{2192}  toggle ON")
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                MaterialScreenInsetBackground(cornerRadius: 14, tint: ScreenTheme.panelTint(for: colorScheme))
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // What it unlocks bento
            HStack(spacing: 10) {
                bentoTile(
                    icon: "clock.arrow.circlepath",
                    title: "Clipboard history",
                    body: "Every inserted record is saved so you can re-insert it at any time."
                )
                bentoTile(
                    icon: "key.fill",
                    title: "Saved logins",
                    body: "Username and password stored in the iOS Keychain — tap once to fill."
                )
            }

            // Privacy note
            HStack(spacing: 6) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ScreenTheme.accent)
                Text("All data stays on your device. Nothing is sent to any server or synced to iCloud.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ScreenTheme.inkSoft)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                MaterialScreenInsetBackground(cornerRadius: 10, tint: ScreenTheme.panelTint(for: colorScheme))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            MaterialScreenCardBackground(cornerRadius: 20, tint: ScreenTheme.cardTint(for: colorScheme), shadowOpacity: 0.14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func fullAccessStep(number: Int, text: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(ScreenTheme.accent)
                    .frame(width: 22, height: 22)
                Text("\(number)")
                    .font(.system(size: 11, weight: .black))
                    .foregroundStyle(.white)
            }
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ScreenTheme.ink)
        }
    }

    private var stepArrow: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 10)
            Rectangle()
                .fill(ScreenTheme.accent.opacity(0.3))
                .frame(width: 1.5, height: 10)
                .padding(.leading, 10) // align with centre of numbered circle
        }
    }

    var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Get started")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(ScreenTheme.accent)

            Text("Add the keyboard once,\nuse it everywhere.")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(ScreenTheme.ink)

            Button(action: openKeyboardSettings) {
                HStack(spacing: 12) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Open Keyboard Settings")
                        .font(.system(size: 16, weight: .bold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .padding(.horizontal, 18)
                .frame(height: 54)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Text("Settings → General → Keyboard → Keyboards → Add New Keyboard → Glazing Key")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ScreenTheme.inkSoft)

            Text("Switch using the globe button next to the space bar in any app.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ScreenTheme.inkSoft)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            MaterialScreenCardBackground(cornerRadius: 20, tint: ScreenTheme.cardTint(for: colorScheme), shadowOpacity: 0.14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    var sampleOutputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insert Output")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(ScreenTheme.accent)

            Picker("Output type", selection: $outputTab.animation(.spring(response: 0.3, dampingFraction: 0.8))) {
                Text("Glazing").tag(0)
                Text("Weight").tag(1)
            }
            .pickerStyle(.segmented)

            Group {
                if outputTab == 0 {
                    Text("1@ 1224x924\n\nSight*: 1200x900\nTight: 1198x896\nFormula: (+24)")
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    Text("Glass: DGU 4-16-4 | Size: 1224x924\nArea: 1.131m2 | Weight: 22.6kg\nHandling: Single person lift")
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal:   .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: outputTab)
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .foregroundStyle(ScreenTheme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background {
                MaterialScreenInsetBackground(cornerRadius: 16, tint: ScreenTheme.panelTint(for: colorScheme))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack(spacing: 10) {
                bentoTile(
                    icon: "hand.tap",
                    title: "Tap ✓",
                    body: outputTab == 0
                        ? "Inserts the full record — cut size, sight, tight, and formula."
                        : "Inserts just the weight — e.g. \"22.6kg\"."
                )
                bentoTile(
                    icon: "hand.tap.fill",
                    title: "Long-press ✓",
                    body: outputTab == 0
                        ? "Inserts just the cut size line — \"1@ 600x900\". Quick for lists."
                        : "Inserts the full weight record with area and handling note."
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            MaterialScreenCardBackground(cornerRadius: 20, tint: ScreenTheme.cardTint(for: colorScheme), shadowOpacity: 0.14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    var formulaInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Formula Sources")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(ScreenTheme.accent)

            Text("Each formula preset is tied to either a Sight or Tight measurement. Enter that measurement and the keyboard calculates the glazing cut size instantly.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ScreenTheme.inkSoft)

            HStack(spacing: 10) {
                bentoTile(
                    icon: "arrow.right.circle",
                    title: "Sight → Cut",
                    body: "Add the formula value to the Sight size. Common for double-glazed units."
                )
                bentoTile(
                    icon: "arrow.left.circle",
                    title: "Tight → Cut",
                    body: "Add the formula value to the Tight rebate. Common for single-pane frames."
                )
            }

            Text("Where possible, always investigate the opposite measurement (Sight or Tight). It varies by frame type and confirms your clearance is correct.")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ScreenTheme.inkSoft)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    MaterialScreenInsetBackground(cornerRadius: 12, tint: ScreenTheme.panelTint(for: colorScheme))
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            MaterialScreenCardBackground(cornerRadius: 20, tint: ScreenTheme.cardTint(for: colorScheme), shadowOpacity: 0.14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    var testAreaCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Try It Here")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(ScreenTheme.accent)

            Text("Tap below, switch to Glazing Key with the globe button, and start measuring.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(ScreenTheme.inkSoft)

            TextEditor(text: $quoteText)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 180)
                .background {
                    MaterialScreenInsetBackground(cornerRadius: 16, tint: ScreenTheme.panelTint(for: colorScheme))
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(ScreenTheme.line, lineWidth: 1)
                )

            if !quoteText.isEmpty {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.3)) { quoteText = "" }
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ScreenTheme.inkSoft)
                }
                .buttonStyle(.plain)
                .transition(.opacity.combined(with: .scale(scale: 0.88)))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            MaterialScreenCardBackground(cornerRadius: 20, tint: ScreenTheme.cardTint(for: colorScheme), shadowOpacity: 0.14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .animation(.spring(response: 0.35), value: quoteText.isEmpty)
    }

    var workflowCard: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header
            Label("Workflow", systemImage: "arrow.triangle.2.circlepath")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(ScreenTheme.accent)
                .labelStyle(.iconOnly)

            HStack(alignment: .top) {
                Label("How it works", systemImage: "arrow.triangle.2.circlepath")
                    .labelStyle(.titleOnly)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(ScreenTheme.ink)
                Spacer()
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ScreenTheme.accent.opacity(0.5))
            }

            // Formula auto-calc row (full-width)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "function")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ScreenTheme.accent)
                    Text("Formula auto-calculator")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ScreenTheme.ink)
                }
                Text("Pick a preset once (e.g. Double Glazing +24mm Sight). Enter height and width — the cut size appears instantly. No calculator, no post-trip arithmetic, no re-entry back at the office.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ScreenTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                // Mini flow diagram
                HStack(spacing: 0) {
                    flowStep("Sight", icon: "ruler")
                    flowArrow
                    flowStep("Formula", icon: "function")
                    flowArrow
                    flowStep("Cut size", icon: "checkmark.square")
                }
                .padding(.vertical, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                MaterialScreenInsetBackground(cornerRadius: 14, tint: ScreenTheme.panelTint(for: colorScheme))
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // 2×2 bento grid
            HStack(spacing: 10) {
                bentoTile(
                    icon: "exclamationmark.triangle",
                    title: "Clearance check",
                    body: "Enter both Sight and Tight. The keyboard compares H vs W clearance and warns if they differ — catching typos and mis-measures before you leave the job."
                )
                bentoTile(
                    icon: "clock.arrow.circlepath",
                    title: "History clipboard",
                    body: "Every inserted record is saved on-device. Tap the clock icon to re-insert any previous result — no retyping from memory on-site."
                )
            }

            HStack(spacing: 10) {
                bentoTile(
                    icon: "square.stack",
                    title: "Glass type → weight",
                    body: "Set the glass build once in the Type tab. Switch to Weight and the kg/m² is already set — just enter the size."
                )
                bentoTile(
                    icon: "lock.shield",
                    title: "All on-device",
                    body: "No internet, no accounts. Measurements and history never leave the device. Works in basements, sites, and poor signal areas."
                )
            }

            // Speed note
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ScreenTheme.accent)
                    Text("Speed note")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ScreenTheme.ink)
                }
                Text("Entering digits is slightly slower than a full keyboard — but every press of ✓ eliminates a calculator step, a clipboard paste, manual formatting, and the risk of a transcription error. For most jobs the time saving is in post-processing, not input.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ScreenTheme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                MaterialScreenInsetBackground(cornerRadius: 12, tint: ScreenTheme.panelTint(for: colorScheme))
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            MaterialScreenCardBackground(cornerRadius: 20, tint: ScreenTheme.cardTint(for: colorScheme), shadowOpacity: 0.14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func flowStep(_ label: String, icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ScreenTheme.accent)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(ScreenTheme.inkSoft)
        }
        .frame(minWidth: 52)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            MaterialScreenInsetBackground(cornerRadius: 8, tint: ScreenTheme.panelTint(for: colorScheme))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var flowArrow: some View {
        Image(systemName: "arrow.right")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(ScreenTheme.accent.opacity(0.5))
            .padding(.horizontal, 4)
    }

    func statPill(icon: String, label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(ScreenTheme.accent)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ScreenTheme.inkSoft)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background {
            MaterialScreenInsetBackground(cornerRadius: 15, tint: ScreenTheme.panelTint(for: colorScheme))
        }
        .clipShape(Capsule())
    }

    func bentoTile(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ScreenTheme.accent)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(ScreenTheme.ink)
            Text(body)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ScreenTheme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            MaterialScreenInsetBackground(cornerRadius: 14, tint: ScreenTheme.panelTint(for: colorScheme))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private extension View {
    func cardEntrance(delay: Double, appeared: Bool) -> some View {
        self
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 28)
            .animation(.spring(response: 0.55, dampingFraction: 0.82).delay(delay), value: appeared)
    }
}

private struct MaterialScreenBackground: View {
    var body: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
    }
}

private struct MaterialScreenCardBackground: View {
    let cornerRadius: CGFloat
    let tint: Color
    let shadowOpacity: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0 : shadowOpacity), radius: 12, x: 0, y: 4)
    }
}

private struct MaterialScreenInsetBackground: View {
    let cornerRadius: CGFloat
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(.tertiarySystemGroupedBackground))
    }
}



private enum ScreenTheme {
    static let accent = Color(red: 28 / 255, green: 144 / 255, blue: 175 / 255)
    static let ink = Color.primary
    static let inkSoft = Color.secondary
    static let line = Color.black.opacity(0.08)

    static func backgroundColors(for colorScheme: ColorScheme) -> [Color] {
        switch colorScheme {
        case .dark:
            return [
                Color(red: 18 / 255, green: 27 / 255, blue: 35 / 255),
                Color(red: 10 / 255, green: 15 / 255, blue: 22 / 255)
            ]
        default:
            return [
                Color(red: 242 / 255, green: 249 / 255, blue: 252 / 255),
                Color(red: 228 / 255, green: 238 / 255, blue: 244 / 255)
            ]
        }
    }

    static func cardTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
        ? Color(red: 110 / 255, green: 135 / 255, blue: 150 / 255)
        : Color(red: 224 / 255, green: 236 / 255, blue: 241 / 255)
    }

    static func panelTint(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
        ? Color(red: 85 / 255, green: 112 / 255, blue: 130 / 255)
        : Color(red: 224 / 255, green: 236 / 255, blue: 241 / 255)
    }
}

struct HomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreen()
    }
}