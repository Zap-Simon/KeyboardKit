import UIKit
import SwiftUI
import KeyboardKit

class KeyboardViewController: KeyboardInputViewController {

    private let presetsStore = PresetsStore()
    private let diagnostics = KeyboardDiagnostics()
    private let renderState = KeyboardRenderState()
    private let keyboardHeight: CGFloat = 408

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        view.isOpaque = false
        renderState.isContentVisible = false
        setup(for: .glazingKeyField)
        // Clear after setup — setup(for:) may replace inputView
        clearHostBackgrounds()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        clearHostBackgrounds()
        renderState.isContentVisible = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        clearHostBackgrounds()
        DispatchQueue.main.async { [weak self] in
            self?.renderState.isContentVisible = true
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        renderState.isContentVisible = false
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        clearHostBackgrounds()
    }

    /// Clears UIKit backgrounds on all intermediate host views so the iOS
    /// system keyboard chrome doesn't bleed through as a visible middle layer.
    private func clearHostBackgrounds() {
        view.backgroundColor = .clear
        view.isOpaque = false
        inputView?.backgroundColor = .clear
        inputView?.isOpaque = false
        for subview in view.subviews {
            subview.backgroundColor = .clear
            subview.isOpaque = false
        }
        for child in children {
            child.view.backgroundColor = .clear
            child.view.isOpaque = false
        }
    }

    override func viewWillSetupKeyboardView() {
        setupKeyboardView { [weak self] controller in
            guard let self else { return KeyboardRootView(
                presetsStore: PresetsStore(),
                diagnostics: KeyboardDiagnostics(),
                renderState: KeyboardRenderState(),
                keyboardHeight: 408,
                needsInputModeSwitch: controller.needsInputModeSwitchKey,
                onInsert: { controller.textDocumentProxy.insertText($0) },
                onSwitchKeyboard: { controller.advanceToNextInputMode() },
                onDelete: { controller.textDocumentProxy.deleteBackward() }
            )}
            return KeyboardRootView(
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