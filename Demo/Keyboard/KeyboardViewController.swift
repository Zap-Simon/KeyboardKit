import UIKit
import SwiftUI
import KeyboardKit

class KeyboardViewController: KeyboardInputViewController {

    private let presetsStore = PresetsStore()
    private let diagnostics = KeyboardDiagnostics()
    private let renderState = KeyboardRenderState()
    private let keyboardHeight: CGFloat = 392

    override func viewDidLoad() {
        super.viewDidLoad()
        renderState.isContentVisible = true
        setup(for: .glazingKeyField)
    }

    override func viewWillSetupKeyboardView() {
        setupKeyboardView { controller in
            KeyboardRootView(
                presetsStore: self.presetsStore,
                diagnostics: self.diagnostics,
                renderState: self.renderState,
                keyboardHeight: self.keyboardHeight,
                needsInputModeSwitch: controller.needsInputModeSwitchKey,
                onInsert: { controller.textDocumentProxy.insertText($0) },
                onSwitchKeyboard: { controller.advanceToNextInputMode() },
                onDelete: { controller.textDocumentProxy.deleteBackward() }
            )
        }
    }

    override func textWillChange(_ textInput: UITextInput?) {}
    override func textDidChange(_ textInput: UITextInput?) {}
}