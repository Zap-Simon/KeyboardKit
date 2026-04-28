import SwiftUI
import UIKit

struct HomeScreen: View {

    @Environment(\.colorScheme) private var colorScheme

    @State private var quoteText = ""
    @State private var quickNote = ""
    @State private var customer = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    workflowCard
                    sampleOutputCard
                    testAreaCard
                }
                .padding(16)
            }
            .background(MaterialScreenBackground())
            .navigationTitle("GlazingKey Field")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private extension HomeScreen {

    var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Glass trade keyboard")
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(ScreenTheme.accent)

            Text("Sight, tight, glazing size, and weight in one keyboard.")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(ScreenTheme.ink)

            Text("Install the keyboard in Settings, then use the numpad to build a glazing record directly inside Notes, email, WhatsApp, or your quoting tools.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ScreenTheme.inkSoft)

            HStack(spacing: 10) {
                badge(title: "No Full Access", systemImage: "lock.shield")
                badge(title: "On-device only", systemImage: "iphone")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            MaterialScreenCardBackground(cornerRadius: 20, tint: ScreenTheme.cardTint(for: colorScheme), shadowOpacity: 0.14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    var workflowCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Setup")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(ScreenTheme.accent)

            ForEach(Array(setupSteps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(ScreenTheme.panelTint(for: colorScheme))
                            .frame(width: 28, height: 28)
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ScreenTheme.ink)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(step.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(ScreenTheme.ink)
                        Text(step.body)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(ScreenTheme.inkSoft)
                    }
                }
            }
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

            Text("1@ 1224x924\n\nSight*: 1200x900\nTight: 1198x896\nFormula: (+24)")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundStyle(ScreenTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background {
                    MaterialScreenInsetBackground(cornerRadius: 16, tint: ScreenTheme.panelTint(for: colorScheme))
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text("Tap the tick to insert the full record. Long-press it to insert only the glazing size.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ScreenTheme.inkSoft)
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
            Text("Try The Keyboard")
                .font(.system(size: 12, weight: .bold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(ScreenTheme.accent)

            TextField("Customer or site", text: $customer)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background {
                    MaterialScreenInsetBackground(cornerRadius: 14, tint: ScreenTheme.panelTint(for: colorScheme))
                }

            TextField("Quick note", text: $quickNote)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background {
                    MaterialScreenInsetBackground(cornerRadius: 14, tint: ScreenTheme.panelTint(for: colorScheme))
                }

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

            Text("Switch to Glazing Key with the globe button after enabling it in iPhone Settings.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ScreenTheme.inkSoft)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            MaterialScreenCardBackground(cornerRadius: 20, tint: ScreenTheme.cardTint(for: colorScheme), shadowOpacity: 0.14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    func badge(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .font(.system(size: 12, weight: .bold))
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background {
            MaterialScreenInsetBackground(cornerRadius: 16, tint: ScreenTheme.panelTint(for: colorScheme))
        }
        .clipShape(Capsule())
    }

    var setupSteps: [(title: String, body: String)] {
        [
            ("Open Settings", "Go to General, then Keyboard."),
            ("Add Keyboard", "Choose Keyboards, then Add New Keyboard."),
            ("Select Glazing Key", "Pick Glazing Key from the third-party list."),
            ("Use The Globe", "Open any text field and switch keyboards with the globe button.")
        ]
    }
}

private struct MaterialScreenBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: ScreenTheme.backgroundColors(for: colorScheme),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            RadialGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.06 : 0.18),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 420
            )
        )
        .overlay(colorScheme == .dark ? Color.black.opacity(0.18) : Color.white.opacity(0.06))
        .ignoresSafeArea()
    }
}

private struct MaterialScreenCardBackground: View {
    let cornerRadius: CGFloat
    let tint: Color
    let shadowOpacity: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScreenGlassSurface(
            cornerRadius: cornerRadius,
            blurStyle: colorScheme == .dark ? .systemChromeMaterialDark : .systemThinMaterialLight,
            tint: tint,
            tintOpacity: colorScheme == .dark ? 0.18 : 0.12,
            shadowOpacity: colorScheme == .dark ? shadowOpacity * 1.15 : shadowOpacity,
            highlightOpacity: colorScheme == .dark ? 0.12 : 0.26,
            edgeOpacity: colorScheme == .dark ? 0.10 : 0.24
        )
    }
}

private struct MaterialScreenInsetBackground: View {
    let cornerRadius: CGFloat
    let tint: Color

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScreenGlassSurface(
            cornerRadius: cornerRadius,
            blurStyle: colorScheme == .dark ? .systemThinMaterialDark : .systemUltraThinMaterialLight,
            tint: tint,
            tintOpacity: colorScheme == .dark ? 0.14 : 0.10,
            shadowOpacity: colorScheme == .dark ? 0.10 : 0.05,
            highlightOpacity: colorScheme == .dark ? 0.10 : 0.22,
            edgeOpacity: colorScheme == .dark ? 0.09 : 0.20
        )
    }
}

private struct ScreenGlassSurface: View {
    let cornerRadius: CGFloat
    let blurStyle: UIBlurEffect.Style
    let tint: Color
    let tintOpacity: CGFloat
    let shadowOpacity: CGFloat
    let highlightOpacity: CGFloat
    let edgeOpacity: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.clear)
            .background {
                ScreenGlassBlurView(blurStyle: blurStyle)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(tintOpacity),
                                tint.opacity(tintOpacity * 0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(highlightOpacity),
                                Color.white.opacity(0.01),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(edgeOpacity),
                                Color.white.opacity(edgeOpacity * 0.46),
                                Color.black.opacity(colorScheme == .dark ? 0.14 : 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color.black.opacity(shadowOpacity), radius: 18, x: 0, y: 10)
    }
}

private struct ScreenGlassBlurView: UIViewRepresentable {
    let blurStyle: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: blurStyle)
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