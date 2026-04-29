import SwiftUI
import KeyboardKit

@main
struct GlazingKeyFieldApp: App {

    var body: some Scene {
        WindowGroup {
            KeyboardAppView(for: .glazingKeyField) {
                HomeScreen()
            }
        }
    }
}