//
//  SlideInteractionController.swift
//  ADPresentationKit
//
//  Created by Schwarze on 26.05.22.
//

import UIKit

/**
 A block type used to provide a start action for presenting or dismissing a view controller,
 when an interactive transition is triggered.
 */
typealias SlideInteractionBegin = (_ ic: SlideInteractionController) -> ()

/**
 Interaction controller for a view controller presentation or dismissal animation.

 An interactive presentation or dismissal needs to exist before the actual present or dismiss call
 is made. For that a gesture recognizer must exist and be linked to a certain
 view. To set this up use the method ``attachTo(view:,beginHook:)``.

 For presentation the recommended procedure is to use ``SlidePresentationManager``'s
 ``attachPresentInteraction(_:,beginHook:)`` method.

 The dismissal ``SlideInteractionController`` is instantiated by the ``SlidePresentationController`` when the presentation animation did end.
 */
class SlideInteractionController: UIPercentDrivenInteractiveTransition {
    let cls = "SlideInteractionController"
    let op: SlideOperation
    let config: SlidePresentationConfig

    init(op: SlideOperation, config: SlidePresentationConfig) {
        self.config = config
        self.op = op
        super.init()
    }

    var interactionInProgress: Bool = false
    var animationDriver: SlideAnimationDriver? = nil

    var panning: SlidePresentationPanning?
    var panningDismissDirection: SlidePresentationOrigin?

    // This is provided when starting the interactive transition.
    // Keep a reference to provide access to container view etc. later in the process.
    var transitionContext: UIViewControllerContextTransitioning?

    // The gesture recognizer which starts and drives the animation
    var pan: UIPanGestureRecognizer?
    var gestureRecognizerInstalled: Bool = false
    var gestureRecognizerView: UIView?

    var beginHook: SlideInteractionBegin?

    // Remember the end frame for the presentation animation during
    // `startInteractiveTransition(...)`, so subsequent gesture recognizer
    // events can calculate proper percentage.
    var viewEndFrame: CGRect = .zero

    // Remember the start frame for the dismissal animation during
    // `startInteractiveTransition(...)`, so subsequent gesture recognizer
    // events can calculate proper percentage.
    var viewStartFrame: CGRect = .zero

    // A reference to the presenting view controller, which is used to start the dismiss operation.
    // As an alternative, provide a beginHook.
    var vcDismiss: UIViewController?

    /**
     Prepare the animationDriver when the ``SlidePresentationManager`` creates an
     animation controller instance. The animationDriver is then used in the animation
     controller too.
     */
    func setupAnimationDriver() {
        ad_log("\(self.cls): \(#function)")
        guard animationDriver == nil else {
            ad_log("\(self.cls): \(#function): animation driver exists - skip")
            return
        }
        ad_log("\(self.cls): \(#function): no animation driver exists - creating one")
        let a = SlideAnimationDriver(op: op, config: config)
        animationDriver = a
    }

    /*
     DOC:
     use startInteractiveTransition to set things up
     */
    override func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        super.startInteractiveTransition(transitionContext)
        ad_log("\(self.cls): \(#function)")

        // TOOD: Document that detail
        /*
         An attempt to fetch the start or end frame with this approach
         fails here. The frame is already set to the final position.
         The animation driver keeps references to the start and end frames
         and should be used as a source of that data.
         if let vw = transitionContext.view(forKey: .from) {
            viewStartFrame = vw.frame
         }
         */

        // save the context for future reference
        self.transitionContext = transitionContext
        guard let ad = animationDriver else {
            ad_log("\(self.cls): \(#function): error: animation driver does not exist")
            return
        }

        switch op {
        case .present: viewEndFrame = ad.viewEndFrame
        case .dismiss: viewStartFrame = ad.viewStartFrame
        }
    }

    /**
     DOC:
     Used by the presentation manager to attach to a view.
     The interaction controller shall register a gesture recognizer to the view, which
     will be used to start the presentation and drive the animation.
     */
    func attachTo(view: UIView, beginHook: SlideInteractionBegin?) {
        ad_log("\(self.cls): \(#function)")
        let gr = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(gr)

        self.beginHook = beginHook
        gestureRecognizerInstalled = true
        self.pan = gr
        self.gestureRecognizerView = view
    }

    @objc func handlePan(_ gr: UIPanGestureRecognizer) {
        ad_log("\(self.cls): \(#function): ... \(gr.state.rawValue)")

        if config.panShiftSingleEnabled {
            handlePanWithDismiss(gr: gr)
            return
        }

        guard let gr_vw = gr.view else { return }

        let vw_fr_pstd = op == .present ? viewEndFrame : viewStartFrame
        let vw_fr : CGRect = .zero
        let vw_con = transitionContext?.containerView
        let con_fr = vw_con?.frame ?? .zero

        ad_log("\(self.cls): \(#function): ... \(String(describing: vw_fr)) - \(String(describing: vw_fr_pstd)) - \(String(describing: vw_con?.frame))")

        func tryBeginOperation(xlt: CGPoint) {
            guard interactionInProgress == false else {
                ad_log("\(self.cls): \(#function): ... interaction is in progress")
                return
            }
            if !SlideUtil.xlat(xlt, matches: config.slideInOrigin, op: op) {
                ad_log("\(self.cls): \(#function): ... translation does not match origin")
                return
            }
            ad_log("\(self.cls): \(#function): ... starting (interactionInProgress)")

            interactionInProgress = true
            beginHook?(self)
            if op == .dismiss && beginHook == nil {
                if let vc = vcDismiss {
                    ad_log("\(self.cls): \(#function): calling dismiss on \(vc)")
                    vc.dismiss(animated: true)
                }
            }
        }

        let xlt = gr.translation(in: gr_vw)
        let scalar = SlideUtil.scalar(xlt: xlt, origin: config.slideInOrigin, op: op)
        let perc = SlideUtil.percentage(scalar: scalar, origin: config.slideInOrigin, vcFr: vw_fr_pstd, conFr: con_fr, op: op)
        // Velocity not yet
        // let xltv = gr.velocity(in: gr_vw)
        // let v = gr.velocity

        switch gr.state {
        case .began:
            ad_log("\(self.cls): \(#function): ... translation \(String(describing: xlt))")
            if interactionInProgress {
                ad_log("\(self.cls): \(#function): ... present is in progress")
            } else {
                tryBeginOperation(xlt: xlt)
            }
            break
        case .changed:
            ad_log("\(self.cls): \(#function): ... updating")
            ad_log("\(self.cls): \(#function): ... translation \(String(describing: xlt))")

            if interactionInProgress {
                ad_log("\(self.cls): \(#function): ... updating: percent=\(perc)")
                if let ad = animationDriver, ad.animationInProgress {
                    update(perc)
                }
            } else {
                tryBeginOperation(xlt: xlt)
            }
            break
        case .cancelled:
            fallthrough
        case .ended:
            fallthrough
        default:
            ad_log("\(self.cls): \(#function): ... finishing")
            guard interactionInProgress else {
                ad_log("\(self.cls): \(#function): present not in progress - skip")
                return
            }

            let cancelled = transitionContext?.transitionWasCancelled ?? false
            if cancelled {
                ad_log("\(self.cls): \(#function): ... was cancelled!")
            }

            // FIXME: Should the cancel above be also "cancelled" when transitionContext cancel is already flagged?
            if perc < 0.5  {
                // do a cancel operation
                if let trCtx = transitionContext {
                    ad_log("\(self.cls): \(#function): ... cancelling")
                    trCtx.cancelInteractiveTransition()
                }
                // FIXME: would cancel() call trCtx.cancelInteractiveTransition?
                cancel()
                self.interactionInProgress = false
                // and do not clean up
                return
            }

            ad_log("\(self.cls): \(#function): ... adding completion and continuing Animator")
            finish()

            self.interactionInProgress = false
            if let pan = self.pan, let vw = gestureRecognizerView {
                if !cancelled {
                    switch op {
                    case .present:
                        ad_log("\(self.cls): \(#function): ... keeping gesture recognizer")
                        break
                    case .dismiss:
                        ad_log("\(self.cls): \(#function): ... removing dismiss gesture recognizer")
                        // FIXME: Is this the right place for the GR to be removed, or can another place do it better?
                        vw.removeGestureRecognizer(pan)
                        gestureRecognizerInstalled = false
                        break
                    }
                }
            }
            break
        }
    }

    func handlePanWithDismiss(gr: UIPanGestureRecognizer) {
        guard let gr_vw = gr.view else { return }
        guard let png = panning else { return }

        // let vw_fr : CGRect = .zero
        let gr_vw_fr = gr_vw.frame
        let vw_fr_pstd = gr_vw_fr // op == .present ? viewEndFrame : viewStartFrame
        let vw_con = transitionContext?.containerView ?? gr_vw.superview
        let con_fr = vw_con?.frame ?? .zero
        let con_ctr_fr = png.allowedCenterArea(con_fr: con_fr, vw_fr: gr_vw_fr)
        let ctr = CGPoint(x: vw_fr_pstd.midX, y: vw_fr_pstd.midY)

        ad_log("\(self.cls): \(#function): ... \(String(describing: ctr)) - \(String(describing: vw_fr_pstd)) - \(String(describing: vw_con?.frame))")

        func moveView(vw: UIView, ctr: CGPoint, vw_fr: CGRect) {
            var fr = vw_fr
            fr.origin = CGPoint(
                x: ctr.x - vw_fr.width / 2.0,
                y: ctr.y - vw_fr.height / 2.0
            )
            vw.frame = fr
        }

        func tryBeginOperation(xlt: CGPoint) -> CGFloat {
            guard interactionInProgress == false else {
                ad_log("\(self.cls): \(#function): ... interaction is in progress")
                return 0.0
            }

            var new_ctr = ctr
            new_ctr.x += xlt.x
            new_ctr.y += xlt.y
            let (min, minOrigin, min_ctr, perc) = png.smallestDirection(con_ctr: con_ctr_fr, ctr: new_ctr, vw_fr: gr_vw_fr)
            if let pdo = panningDismissDirection {
                // Check whether the panning continues over the edge
                if min < 0 && pdo == minOrigin {
                    // It does, return percentage
                    return perc
                } else {
                    // Not any more
                    ad_log("\(self.cls): \(#function): clearing runtimeSlideInOrigin")
                    panningDismissDirection = nil
                    config.runtimeSlideInOrigin = nil
                    moveView(vw: gr_vw, ctr: min_ctr, vw_fr: gr_vw_fr)
                    return 0.0
                }
            } else {
                // It begins
                if min < 0.0 {
                    ad_log("\(self.cls): \(#function): setting runtimeSlideInOrigin to \(minOrigin.debug)")
                    panningDismissDirection = minOrigin
                    config.runtimeSlideInOrigin = minOrigin
                    moveView(vw: gr_vw, ctr: min_ctr, vw_fr: gr_vw_fr)

                    interactionInProgress = true
                    beginHook?(self)
                    if op == .dismiss && beginHook == nil {
                        if let vc = vcDismiss {
                            ad_log("\(self.cls): \(#function): calling dismiss on \(vc)")
                            vc.dismiss(animated: true)
                        }
                    }
                    return 0.0
                } else {
                    // Just panning
                    moveView(vw: gr_vw, ctr: new_ctr, vw_fr: gr_vw_fr)
                    return 0.0
                }
            }
        }

        let xlt = gr.translation(in: gr_vw)
        let scalar: CGFloat
        let perc: CGFloat
        if let pdo = panningDismissDirection {
            scalar = SlideUtil.scalar(xlt: xlt, origin: pdo, op: op)
            perc = SlideUtil.percentage(scalar: scalar, origin: pdo, vcFr: vw_fr_pstd, conFr: con_fr, op: op)
        } else {
            scalar = 0.0
            perc = 0.0
        }
        // Velocity not yet
        // let xltv = gr.velocity(in: gr_vw)
        // let v = gr.velocity

        // Reset translation
        gr.setTranslation(.zero, in: gr_vw)

        switch gr.state {
        case .began:
            ad_log("\(self.cls): \(#function): ... translation \(String(describing: xlt))")
            if interactionInProgress {
                ad_log("\(self.cls): \(#function): ... present is in progress")
            } else {
                _ = tryBeginOperation(xlt: xlt)
            }
            break
        case .changed:
            ad_log("\(self.cls): \(#function): ... updating")
            ad_log("\(self.cls): \(#function): ... translation \(String(describing: xlt))")

            let p = tryBeginOperation(xlt: xlt)
            if p > 0.0 && interactionInProgress {
                ad_log("\(self.cls): \(#function): ... updating: percent=\(perc)")
                if let ad = animationDriver, ad.animationInProgress {
                    update(p)
                }
            }
            break
        case .cancelled:
            fallthrough
        case .ended:
            fallthrough
        default:
            ad_log("\(self.cls): \(#function): ... finishing")
            guard interactionInProgress else {
                ad_log("\(self.cls): \(#function): present not in progress - skip")
                return
            }

            let cancelled = transitionContext?.transitionWasCancelled ?? false
            if cancelled {
                ad_log("\(self.cls): \(#function): ... was cancelled!")
            }

            // FIXME: Should the cancel above be also "cancelled" when transitionContext cancel is already flagged?
            if perc < 0.5  {
                // do a cancel operation
                if let trCtx = transitionContext {
                    ad_log("\(self.cls): \(#function): ... cancelling")
                    trCtx.cancelInteractiveTransition()
                }
                // FIXME: would cancel() call trCtx.cancelInteractiveTransition?
                cancel()
                self.interactionInProgress = false
                // and do not clean up
                return
            }

            ad_log("\(self.cls): \(#function): ... adding completion and continuing Animator")
            finish()

            self.interactionInProgress = false
            if let pan = self.pan, let vw = gestureRecognizerView {
                if !cancelled {
                    switch op {
                    case .present:
                        ad_log("\(self.cls): \(#function): ... keeping gesture recognizer")
                        break
                    case .dismiss:
                        ad_log("\(self.cls): \(#function): ... removing dismiss gesture recognizer")
                        // FIXME: Is this the right place for the GR to be removed, or can another place do it better?
                        vw.removeGestureRecognizer(pan)
                        gestureRecognizerInstalled = false
                        break
                    }
                }
            }
            break
        }
    }

    // FIXME: check this comment from UIKit on the update()/finish()/cancel() methods:
    // UIKit:
    // These methods should be called by the gesture recognizer or some other logic
    // to drive the interaction. This style of interaction controller should only be
    // used with an animator that implements a CA style transition in the animator's
    // animateTransition: method. If this type of interaction controller is
    // specified, the animateTransition: method must ensure to call the
    // UIViewControllerTransitionParameters completeTransition: method. The other
    // interactive methods on UIViewControllerContextTransitioning should NOT be
    // called. If there is an interruptible animator, these methods will either scrub or continue
    // the transition in the forward or reverse directions.
    /*
    open func update(_ percentComplete: CGFloat)
    open func cancel()
    open func finish()
     */
}

class SlidePresentInteractionController: SlideInteractionController {
    init(config: SlidePresentationConfig) {
        super.init(op: .present, config: config)
    }
}

class SlideDismissInteractionController: SlideInteractionController {
    init(config: SlidePresentationConfig) {
        super.init(op: .dismiss, config: config)
    }
}
