import UIKit
import SwiftUI
import KeyboardKit

class KeyboardViewController: KeyboardInputViewController {

    private var hasSetupView = false
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

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        clearHostBackgrounds()
    }

    /// Recursively clears UIKit backgrounds on the entire host view hierarchy
    /// so the system keyboard chrome never bleeds through as a grey layer.
    private func clearHostBackgrounds() {
        clearUIKitTree(view)
        if let iv = inputView { clearUIKitTree(iv) }
        for child in children { clearUIKitTree(child.view) }
    }

    private func clearUIKitTree(_ v: UIView) {
        v.backgroundColor = .clear
        v.isOpaque = false
        for sub in v.subviews {
            clearUIKitTree(sub)
        }
    }

    override func viewWillSetupKeyboardView() {
        guard !hasSetupView else { return }
        hasSetupView = true
        setupKeyboardView { [weak self] controller in
            guard let self else { return KeyboardRootView(
                presetsStore: PresetsStore(),
                diagnostics: KeyboardDiagnostics(),
                renderState: KeyboardRenderState(),
                keyboardHeight: 408,
                onInsert: { controller.textDocumentProxy.insertText($0) },
                onSwitchKeyboard: { controller.advanceToNextInputMode() },
                onDelete: { controller.textDocumentProxy.deleteBackward() },
                onDismiss: { [weak controller] in
                    controller?.view.window?.endEditing(true)
                }
            )}
            return KeyboardRootView(
                presetsStore: self.presetsStore,
                diagnostics: self.diagnostics,
                renderState: self.renderState,
                keyboardHeight: self.keyboardHeight,
                onInsert: { controller.textDocumentProxy.insertText($0) },
                onSwitchKeyboard: { controller.advanceToNextInputMode() },
                onDelete: { controller.textDocumentProxy.deleteBackward() },
                onDismiss: { [weak self] in
                    self?.dismissKeyboard()
                }
            )
        }
    }

}