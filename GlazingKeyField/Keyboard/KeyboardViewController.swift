import UIKit
import SwiftUI
import KeyboardKit

class KeyboardViewController: KeyboardInputViewController {

    private let presetsStore = PresetsStore()
    private let diagnostics = KeyboardDiagnostics()
    private let renderState = KeyboardRenderState()
    private let keyboardHeight: CGFloat = 408

    override func viewDidLoad() {
        renderState.isContentVisible = false
        view.backgroundColor = .clear
        view.isOpaque = false
        super.viewDidLoad()
        clearHostBackgrounds()
    }

    override func viewWillSetupKeyboardKit() {
        setupKeyboardKit(for: .glazingKeyField) { _ in }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        clearHostBackgrounds()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        clearHostBackgrounds()
        if !renderState.isContentVisible {
            DispatchQueue.main.async { [weak self] in
                self?.renderState.isContentVisible = true
            }
        }
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
                onInsert: { controller.textDocumentProxy.insertText($0) },
                onSwitchKeyboard: { controller.advanceToNextInputMode() },
                onDelete: { controller.textDocumentProxy.deleteBackward() }
            )}
            return KeyboardRootView(
                presetsStore: self.presetsStore,
                diagnostics: self.diagnostics,
                renderState: self.renderState,
                keyboardHeight: self.keyboardHeight,
                onInsert: { controller.textDocumentProxy.insertText($0) },
                onSwitchKeyboard: { controller.advanceToNextInputMode() },
                onDelete: { controller.textDocumentProxy.deleteBackward() }
            )
        }
    }

}