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

        view.backgroundColor = .clear
        view.isOpaque = false
        inputView?.backgroundColor = .clear
        inputView?.isOpaque = false

        renderState.isContentVisible = false
        setup(for: .glazingKeyField)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        renderState.isContentVisible = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async { [weak self] in
            self?.renderState.isContentVisible = true
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        renderState.isContentVisible = false
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