import SwiftUI

struct HomeScreen: View {

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
            .background(ScreenTheme.background.ignoresSafeArea())
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
        .background(ScreenTheme.card)
        .overlay(cardStroke)
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
                            .fill(ScreenTheme.panel)
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
        .background(ScreenTheme.card)
        .overlay(cardStroke)
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
                .background(ScreenTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text("Tap the tick to insert the full record. Long-press it to insert only the glazing size.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ScreenTheme.inkSoft)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ScreenTheme.card)
        .overlay(cardStroke)
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
                .textFieldStyle(.roundedBorder)

            TextField("Quick note", text: $quickNote)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $quoteText)
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 180)
                .background(ScreenTheme.panel)
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
        .background(ScreenTheme.card)
        .overlay(cardStroke)
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
        .background(ScreenTheme.panel)
        .clipShape(Capsule())
    }

    var cardStroke: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(ScreenTheme.line, lineWidth: 1)
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

private enum ScreenTheme {
    static let background = LinearGradient(
        colors: [
            Color(red: 242 / 255, green: 249 / 255, blue: 252 / 255),
            Color(red: 228 / 255, green: 238 / 255, blue: 244 / 255)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let card = Color.white.opacity(0.74)
    static let panel = Color(red: 224 / 255, green: 236 / 255, blue: 241 / 255)
    static let accent = Color(red: 28 / 255, green: 144 / 255, blue: 175 / 255)
    static let ink = Color(red: 20 / 255, green: 32 / 255, blue: 40 / 255)
    static let inkSoft = Color(red: 82 / 255, green: 99 / 255, blue: 111 / 255)
    static let line = Color.black.opacity(0.08)
}

struct HomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreen()
    }
}