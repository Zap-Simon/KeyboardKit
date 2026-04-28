import UIKit
import SwiftUI

private final class FixedHeightKeyboardInputView: UIInputView {
    private let fixedHeight: CGFloat

    init(height: CGFloat) {
        self.fixedHeight = height
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: height), inputViewStyle: .keyboard)
        allowsSelfSizing = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: fixedHeight)
    }
}

class KeyboardViewController: UIInputViewController {

    private var hostingController: UIHostingController<KeyboardRootView>?
    private var hostingViewConstraints: [NSLayoutConstraint] = []
    private var heightConstraint: NSLayoutConstraint?
    private var placeholderView: UIView?
    private let presetsStore = PresetsStore()
    private let diagnostics = KeyboardDiagnostics()
    private let renderState = KeyboardRenderState()
    private let keyboardHeight: CGFloat = 392
    private var didRevealHostedKeyboard = false
    private var isHostingViewAttached = false
    private var isRevealCheckScheduled = false
    private var appearanceGeneration = 0
    private var revealRetryCount = 0
    private let maxRevealRetries = 8
    private let lifecycleDiagnosticsEnabled = false

    override var preferredContentSize: CGSize {
        get { CGSize(width: UIView.noIntrinsicMetric, height: keyboardHeight) }
        set { }
    }

    override func loadView() {
        let keyboardView = FixedHeightKeyboardInputView(height: keyboardHeight)
        keyboardView.backgroundColor = .clear
        keyboardView.isOpaque = false
        heightConstraint = keyboardView.heightAnchor.constraint(equalToConstant: keyboardHeight)
        heightConstraint?.priority = .required
        heightConstraint?.isActive = true
        view = keyboardView
        logLifecycle("loadView")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appearanceGeneration &+= 1
        didRevealHostedKeyboard = false
        isHostingViewAttached = false
        isRevealCheckScheduled = false
        revealRetryCount = 0
        renderState.isContentVisible = false
        detachHostingViewIfNeeded()
        ensurePlaceholderView()
        enforceKeyboardHeight()
        DispatchQueue.main.async { [weak self] in
            self?.scheduleRevealCheck(reason: "viewWillAppear")
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        appearanceGeneration &+= 1
        isRevealCheckScheduled = false
        revealRetryCount = 0
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scheduleRevealCheck(reason: "viewDidAppear")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        view.isOpaque = false
        inputView?.backgroundColor = .clear
        inputView?.isOpaque = false
        ensurePlaceholderView()

        enforceKeyboardHeight()
        (inputView ?? view).layoutIfNeeded()
        view.layoutIfNeeded()
    }

    override func updateViewConstraints() {
        enforceKeyboardHeight()
        super.updateViewConstraints()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        enforceKeyboardHeight()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        enforceKeyboardHeight()

        guard !didRevealHostedKeyboard,
              view.bounds.width > 0,
              view.bounds.height > 0
        else { return }

        scheduleRevealCheck(reason: "layout")
    }

    private func scheduleRevealCheck(reason: String) {
        guard !didRevealHostedKeyboard,
              !isRevealCheckScheduled,
              view.bounds.width > 0,
              view.bounds.height > 0
        else { return }

        let generation = appearanceGeneration
        isRevealCheckScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.runRevealCheck(for: generation, reason: reason)
        }
    }

    private func runRevealCheck(for generation: Int, reason: String) {
        guard generation == appearanceGeneration else { return }

        isRevealCheckScheduled = false

        guard !didRevealHostedKeyboard,
              view.bounds.width > 0,
              view.bounds.height > 0
        else { return }

        if isKeyboardHeightSettled {
            attachHostingViewIfNeeded()
            didRevealHostedKeyboard = true
            revealRetryCount = 0
            UIView.performWithoutAnimation {
                renderState.isContentVisible = true
                view.layoutIfNeeded()
            }
            return
        }

        guard revealRetryCount < maxRevealRetries else { return }

        revealRetryCount += 1
        logLifecycle("revealRetry\(revealRetryCount):\(reason)")
        scheduleRevealCheck(reason: "retry")
    }

    private func enforceKeyboardHeight() {
        heightConstraint?.constant = keyboardHeight
        view.invalidateIntrinsicContentSize()
        inputView?.invalidateIntrinsicContentSize()
    }

    private func ensurePlaceholderView() {
        guard placeholderView == nil, let containerView = inputView ?? view else { return }

        let placeholderView = UIView()
        placeholderView.backgroundColor = UIColor.secondarySystemBackground
        placeholderView.isOpaque = true
        placeholderView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(placeholderView)
        NSLayoutConstraint.activate([
            placeholderView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            placeholderView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            placeholderView.topAnchor.constraint(equalTo: containerView.topAnchor),
            placeholderView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        self.placeholderView = placeholderView
    }

    private func attachHostingViewIfNeeded() {
        guard !isHostingViewAttached,
              let containerView = inputView ?? view
        else { return }

        let hostingController = makeHostingControllerIfNeeded()
        let hostingView = hostingController.view!

        hostingView.removeFromSuperview()
        containerView.addSubview(hostingView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingViewConstraints = [
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ]
        NSLayoutConstraint.activate(hostingViewConstraints)
        placeholderView?.removeFromSuperview()
        placeholderView = nil
        isHostingViewAttached = true
    }

    private func detachHostingViewIfNeeded() {
        hostingViewConstraints.forEach { $0.isActive = false }
        hostingViewConstraints.removeAll()

        guard let hostingController else { return }

        hostingController.view.removeFromSuperview()
        isHostingViewAttached = false
    }

    private func makeHostingControllerIfNeeded() -> UIHostingController<KeyboardRootView> {
        if let hostingController {
            return hostingController
        }

        let rootView = KeyboardRootView(
            presetsStore: presetsStore,
            diagnostics: diagnostics,
            renderState: renderState,
            keyboardHeight: keyboardHeight,
            needsInputModeSwitch: needsInputModeSwitchKey,
            onInsert: { [weak self] text in
                self?.textDocumentProxy.insertText(text)
            },
            onSwitchKeyboard: { [weak self] in
                self?.advanceToNextInputMode()
            },
            onDelete: { [weak self] in
                self?.textDocumentProxy.deleteBackward()
            }
        )

        let hostingController = UIHostingController(rootView: rootView)
        if #available(iOS 16.0, *) {
            hostingController.sizingOptions = []
        }
        hostingController.view.backgroundColor = .clear
        hostingController.view.isOpaque = false
        hostingController.view.clipsToBounds = true
        addChild(hostingController)
        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
        return hostingController
    }

    private var isKeyboardHeightSettled: Bool {
        abs(view.bounds.height - keyboardHeight) <= 0.5 &&
        abs((inputView?.bounds.height ?? keyboardHeight) - keyboardHeight) <= 0.5
    }

    private func logLifecycle(_ event: String) {
        guard lifecycleDiagnosticsEnabled else { return }

        let viewHeight = String(format: "%.1f", view.bounds.height)
        let inputHeight = String(format: "%.1f", inputView?.bounds.height ?? -1)
        let hostedHeight = String(format: "%.1f", hostingController?.view.bounds.height ?? -1)
        let viewWidth = String(format: "%.1f", view.bounds.width)
        diagnostics.record("\(event) v:\(viewWidth)x\(viewHeight) i:\(inputHeight) h:\(hostedHeight)")
    }

    override func textWillChange(_ textInput: UITextInput?) {}
    override func textDidChange(_ textInput: UITextInput?) {}
}