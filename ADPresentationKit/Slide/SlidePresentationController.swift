//
//  SlidePresentationController.swift
//  ADPresentationKit
//
//  Created by Schwarze on 16.04.22.
//

import Foundation
import UIKit

/**
 Custom presentation controller for the slide presentation, as returned
 by the `SlidePresentationManager`.

 The presentation controller is responsible for these aspects:
 - install a backdrop
 - hold reference to `SlideDismissAnimationController`
 - hold reference to `SlidePresentAnimationController`
 - hold reference to `SlidePresentInteractionController`
 - hold reference to `SlideDismissInteractionController`
 The references are bundled in `SlideContext`.
 */
class SlidePresentationController: UIPresentationController {
    let cls = "SlidePresentationController"

    let config: SlidePresentationConfig
    var context: SlideContext = SlideContext()

    var backdropView: UIView?
    var panContainerView: UIView?

    var panning: SlidePresentationPanning?
    // Use this flag to enable or disable preventing single finger pan together with interactive dismiss
    var _preventSinglePanDismissCollision: Bool = true

    var observingKeyboard: Bool = false
    let keyboardNotificationNames = [
        UIResponder.keyboardWillShowNotification,
        UIResponder.keyboardDidShowNotification,
        UIResponder.keyboardWillHideNotification,
        UIResponder.keyboardDidHideNotification,
        UIResponder.keyboardWillChangeFrameNotification,
        UIResponder.keyboardDidChangeFrameNotification,
    ]

    init(presentedViewController: UIViewController, presenting: UIViewController?, config: SlidePresentationConfig) {
        self.config = config
        super.init(presentedViewController: presentedViewController, presenting: presenting)
    }

    // MARK: - Backdrop

    func createBackdrop() {
        let b = UIView()
        b.backgroundColor = config.backdropBackgroundColor
        b.alpha = 0.0
        // b.tag = 17 // <- for debugging
        backdropView = b
        let g = UITapGestureRecognizer(target: self, action: #selector(didTapBackdrop(_:)))
        b.addGestureRecognizer(g)
    }

    @objc func didTapBackdrop(_ gr: UIGestureRecognizer) {
        if config.backdropDismiss {
            presentedViewController.dismiss(animated: true, completion: nil)
        }
    }

    func installBackdrop() {
        if backdropView == nil {
            createBackdrop()
        }
        guard let c = self.containerView, let b = self.backdropView else {
            ad_log("\(self.cls): \(#function): no container or backdrop")
            return
        }
        guard b.superview == nil else {
            ad_log("\(self.cls): \(#function): backdrop already installed")
            return
        }
        b.translatesAutoresizingMaskIntoConstraints = false
        b.frame = c.bounds
        c.insertSubview(b, at: 0)
        let cons = [
            c.topAnchor.constraint(equalTo: b.topAnchor),
            c.trailingAnchor.constraint(equalTo: b.trailingAnchor),
            c.bottomAnchor.constraint(equalTo: b.bottomAnchor),
            c.leadingAnchor.constraint(equalTo: b.leadingAnchor)
        ]
        NSLayoutConstraint.activate(cons)
        ad_log("\(self.cls): \(#function): activating constraints: \(String(describing: cons))")
    }

    func uninstallBackdrop() {
        ad_log("\(self.cls): \(#function)")
        guard let b = backdropView else {
            ad_log("\(self.cls): \(#function): no backdrop")
            return
        }
        guard b.superview != nil else {
            ad_log("\(self.cls): \(#function): backdrop not installed")
            return
        }
        b.removeFromSuperview()
    }

    // MARK: - Pan Container

    func createPanContainer() {
        let v = UIView()
        v.backgroundColor = .clear
        panContainerView = v
    }

    func installPanContainer() {
        if panContainerView == nil {
            createPanContainer()
        }
        if let pcv = panContainerView, let con = containerView {
            pcv.translatesAutoresizingMaskIntoConstraints = false
            con.addSubview(pcv)
            pcv.frame = con.bounds
        }
    }

    func uninstallPanContainer() {
        panContainerView?.subviews.first?.removeFromSuperview()
        panContainerView?.removeFromSuperview()
    }

    // MARK: - Keyboard Avoidance

    func beginObserveKeyboard() {
        guard !observingKeyboard else { return }
        observingKeyboard = true
        for name in keyboardNotificationNames {
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardNotification(_:)), name: name, object: nil)
        }
    }

    func endObserveKeyboard() {
        guard observingKeyboard else { return }
        observingKeyboard = false
        for name in keyboardNotificationNames {
            NotificationCenter.default.removeObserver(self, name: name, object: nil)
        }
    }

    @objc
    func keyboardNotification(_ notification: Notification) {
        let info = String(describing: notification)
        ad_log("\(self.cls): \(#function):\n\(info)")

        switch notification.name {
        case UIResponder.keyboardDidShowNotification:
            guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            config.currentKeyboardFrame = endFrame
            containerView?.setNeedsLayout()
            containerView?.layoutIfNeeded()
            // containerView?.layoutSubviews()
            break
        case UIResponder.keyboardDidHideNotification:
            guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] else { return }
            config.currentKeyboardFrame = nil
            containerView?.setNeedsLayout()
            containerView?.layoutIfNeeded()
            // containerView?.layoutSubviews()
            break
        default:
            break // ignore
        }
    }

    // MARK: - Assorted Overrides

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        ad_log("\(self.cls): \(#function)")

        let f = frameOfPresentedViewInContainerView
        let vw = presentedViewController.view
        if config.usePresentationContainerView {
            // panContainerView?.frame = f
            // vw?.frame = CGRect(origin: .zero, size: f.size)
            if let con = containerView {
                panContainerView?.frame = con.bounds
            }
            vw?.frame = f
        } else {
            vw?.frame = f
        }
    }

    // MARK: - Frame Placement

    func fit(view: UIView, maxFittingSize: CGSize) -> CGSize {
        func tryFit(view: UIView, widthRequired: Bool, heightRequired: Bool) -> CGSize {
            let fittingSize = CGSize(
                width: widthRequired ? maxFittingSize.width : UIView.layoutFittingCompressedSize.width,
                height: heightRequired ? maxFittingSize.height : UIView.layoutFittingCompressedSize.height
            )
            let fitSize = view.systemLayoutSizeFitting(
                fittingSize,
                withHorizontalFittingPriority: widthRequired ? .required : .defaultLow,
                verticalFittingPriority: heightRequired ? .required : .defaultLow
            )
            return fitSize
        }

        var v = tryFit(view: view, widthRequired: false, heightRequired: false)
        var oneChecked = false
        if v.width > maxFittingSize.width {
            oneChecked = true
            v = tryFit(view: view, widthRequired: true, heightRequired: false)
        } else if v.height > maxFittingSize.height {
            oneChecked = true
            v = tryFit(view: view, widthRequired: false, heightRequired: true)
        }
        if oneChecked && (v.width > maxFittingSize.width || v.height > maxFittingSize.height) {
            v = tryFit(view: view, widthRequired: true, heightRequired: true)
        }
        return v
    }

    func _frameForCompressedLayout() -> CGRect {
        guard let con_vw = containerView, let presentedView = presentedView else { return .zero }
        let safeAreaFrame = con_vw.bounds.inset(by: con_vw.safeAreaInsets)

        var bottomInset: CGFloat = 0.0
        if config.keyboardAvoidance, let kbdFrame = config.currentKeyboardFrame {
            bottomInset = kbdFrame.height - config.layoutVerticalGap
        }
        let insetSafeAreaFrame0 = safeAreaFrame.insetBy(dx: config.layoutHorizontalGap, dy: config.layoutVerticalGap)
        let insetSafeAreaFrame = insetSafeAreaFrame0.inset(by: UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0))
        // let insetSafeAreaFrame = safeAreaFrame.insetBy(dx: config.layoutHorizontalGap, dy: config.layoutVerticalGap)

        let maxWidth = safeAreaFrame.width - 2.0 * config.layoutHorizontalGap
        let maxHeight = safeAreaFrame.height - 2.0 * config.layoutVerticalGap
        let maxFittingSize = CGSize(width: maxWidth, height: maxHeight)
        let fitSize = fit(view: presentedView, maxFittingSize: maxFittingSize)

        var fitOrigin: CGPoint = .zero

        switch config.anchorHorizontal {
        case .leading:
            fitOrigin.x = insetSafeAreaFrame.origin.x
        case .trailing:
            fitOrigin.x = insetSafeAreaFrame.minX + insetSafeAreaFrame.width - fitSize.width
        case .middle:
            fallthrough
        default:
            fitOrigin.x = insetSafeAreaFrame.minX + (insetSafeAreaFrame.width - fitSize.width) / 2.0
        }

        switch config.anchorVertical {
        case .top:
            fitOrigin.y = insetSafeAreaFrame.origin.y
        case .bottom:
            fitOrigin.y = insetSafeAreaFrame.minY + insetSafeAreaFrame.height - fitSize.height
        case .middle:
            fallthrough
        default:
            fitOrigin.y = insetSafeAreaFrame.minY + (insetSafeAreaFrame.height - fitSize.height) / 2.0
        }

        if let relPos = config.relativePosition {
            let ctr_fr = insetSafeAreaFrame.insetBy(dx: fitSize.width / 2.0, dy: fitSize.height / 2.0)
            let ctr_pos = CGPoint(
                x: ctr_fr.minX + relPos.x * ctr_fr.width,
                y: ctr_fr.minY + relPos.y * ctr_fr.height
                )
            fitOrigin.x = ctr_pos.x - fitSize.width / 2.0
            fitOrigin.y = ctr_pos.y - fitSize.height / 2.0
        }

        let rect = CGRect(origin: fitOrigin, size: fitSize)
        return rect
    }

    func _frameForExpandedLayout() -> CGRect {
        guard let containerView = containerView else { return .zero }
        let safeAreaFrame = containerView.bounds.inset(by: containerView.safeAreaInsets)
        var bottomInset: CGFloat = 0.0
        if config.keyboardAvoidance, let kbdFrame = config.currentKeyboardFrame {
            bottomInset = kbdFrame.height - config.layoutVerticalGap
        }
        let insetSafeAreaFrame0 = safeAreaFrame.insetBy(dx: config.layoutHorizontalGap, dy: config.layoutVerticalGap)
        let insetSafeAreaFrame = insetSafeAreaFrame0.inset(by: UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0))
        let rect = insetSafeAreaFrame
        return rect
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        var rect = super.frameOfPresentedViewInContainerView
        ad_log("\(self.cls): \(#function): super returned \(String(describing: rect))")
        if config.layoutCompressed {
            // TODO: Any reason why the already provided rect should be used as a starting point?
            guard let _ = containerView, let _ = presentedView else { return rect }
            rect = _frameForCompressedLayout()
        } else {
            guard let _ = containerView else { return rect /*.zero*/ }
            rect = _frameForExpandedLayout()
        }
        return rect
    }

    // MARK: - Presentation

    /*
    override var presentedView: UIView? {
        get {
            return panContainerView
        }
    }
     */

    override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()
        ad_log("\(self.cls): \(#function)")

        if config.keyboardAvoidance {
            beginObserveKeyboard()
        }
        if config.backdrop {
            installBackdrop()
        }
        if config.usePresentationContainerView {
            installPanContainer()
            panContainerView?.addSubview(presentedViewController.view)
        }
        guard let b = self.backdropView else {
            ad_log("\(self.cls): \(#function): no backdrop")
            return
        }

        guard let coordinator = presentedViewController.transitionCoordinator else {
            ad_log("\(self.cls): \(#function): no coordinator")
            b.alpha = 1.0
            return
        }
        coordinator.animate { context in
            b.alpha = 1.0
        } completion: { context in
            b.alpha = 1.0
        }
    }

    override func presentationTransitionDidEnd(_ completed: Bool) {
        super.presentationTransitionDidEnd(completed)

        let vc_pr = presentedViewController
        ad_log("\(self.cls): \(#function)")

        if !completed {
            return
        }

        var singlePanInstalled = false
        if config.interactiveDismissEnabled {
            installInteractiveDismiss(vc: vc_pr)

            if config.panShiftSingleEnabled {
                if _preventSinglePanDismissCollision {
                    ad_log("\(self.cls): \(#function): panShiftSingleEnabled is true, but collides with interactiveDismissEnabled; ignoring panShiftSingleEnabled; consider using panShiftTwoEnabled.")
                } else {
                    installPanningWithInteractionController()
                }
            }
        } else {
            if config.panShiftSingleEnabled {
                if let con_vw = panContainerView {
                    installViewPanning(vc: vc_pr, con_vw: con_vw)
                    singlePanInstalled = true
                } else if let con_vw = containerView {
                    installViewPanning(vc: vc_pr, con_vw: con_vw)
                    singlePanInstalled = true
                } else {
                    ad_log("\(self.cls): \(#function): Error: container view is missing.")
                }
            }
        }
        if config.panShiftTwoEnabled {
            if singlePanInstalled {
                ad_log("\(self.cls): \(#function): panShiftSingleEnabled is true and has been activated; panShiftDoubleEnabled is ignored in that case.")
            } else {
                if let con_vw = panContainerView {
                    installViewPanning(vc: vc_pr, con_vw: con_vw)
                } else if let con_vw = containerView {
                    installViewPanning(vc: vc_pr, con_vw: con_vw)
                } else {
                    ad_log("\(self.cls): \(#function): Error: container view is missing.")
                }
            }
        }
        // Reset the animation driver when completed
        context.presentAnimationDriver = nil
        context.presentAnimationController?.animationDriver = nil
        context.presentInteractionController?.animationDriver = nil
    }

    // MARK: - Dismissal

    override func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()

        ad_log("\(self.cls): \(#function)")

        // DOC:
        // Fade out the backdrop in the dismissal transition

        // Return if there is no backdrop. The rest of the method only
        // deals with the backdrop.
        guard let b = self.backdropView else {
            ad_log("\(self.cls): \(#function): no backdrop")
            return
        }
        guard let coordinator = presentedViewController.transitionCoordinator else {
            ad_log("\(self.cls): \(#function): no coordinator")
            b.alpha = 0.0
            return
        }
        coordinator.animate { context in
            b.alpha = 0.0
        } completion: { context in
            let cancelled = context.isCancelled
            if cancelled {
                b.alpha = 1.0
            } else {
                b.alpha = 0.0
            }
        }
    }

    override func dismissalTransitionDidEnd(_ completed: Bool) {
        super.dismissalTransitionDidEnd(completed)

        ad_log("\(self.cls): \(#function): completed=\(completed)")

        if !completed {
            // If cancelled, restore the backdrop view:
            if let b = backdropView {
                b.alpha = 1.0
            }
            return
        }
        
        if config.keyboardAvoidance {
            endObserveKeyboard()
        }
        uninstallBackdrop()
        uninstallViewPanning()
        uninstallPanContainer() // this also removes the view controller's view

        ad_log("\(self.cls): \(#function): resetting dismiss animation drivers and controllers")
        // Reset the dismiss animation driver at the end.
        // If not cleared, the dismiss interaction will continue to exist and won't be re-initialized.
        context.dismissAnimationDriver = nil
        context.dismissInteractionController?.animationDriver = nil
        context.dismissAnimationController?.animationDriver = nil
        context.dismissInteractionController = nil
        context.dismissAnimationDriver = nil
    }

    // MARK: - Interaction

    func installInteractiveDismiss(vc: UIViewController) {
        ad_log("\(self.cls): \(#function)")
        guard context.dismissInteractionController == nil else {
            ad_log("\(self.cls): \(#function): dismiss interaction controller already exists - skipping")
            return
        }
        let ic = SlideDismissInteractionController(config: config)
        ic.attachTo(view: vc.view, beginHook: nil)
        ic.vcDismiss = vc
        context.dismissInteractionController = ic
    }

    func installPanningWithInteractionController() {
        let p = SlidePresentationPanning(config: config)
        context.dismissInteractionController?.panning = p
    }

    func installViewPanning(vc: UIViewController, con_vw: UIView) {
        if let p = panning {
            p.detach()
        }
        let p = SlidePresentationPanning(config: config)
        p.attachTo(vc: vc, con_vw: con_vw)
        panning = p
    }

    func uninstallViewPanning() {
        if let p = panning {
            p.detach()
        }
        panning = nil
    }
}
