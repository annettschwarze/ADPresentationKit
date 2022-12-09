//
//  SlideAnimationDriver.swift
//  ADPresentationKit
//
//  Created by Schwarze on 25.05.22.
//

import UIKit

/**
 The animationDriver class calculates and drives the actual custom frame
 animation. This is used for non-interactive presentation in
 ``SlidePresentAnimationController``'s method
 ``animateTransition(using transitionContext:)``. For interactive transition
 it is used in ``SlidePresentInteractionController``'s method
 ``animationController(forPresented presented:, presenting:, source:)``.

 The animationDriver determines the start and end positions in a way, that, as soon
 as the main view is fully outside the visible area, the dismiss position
 is assumed. Note that a simple move of the center by the container
 width or height will create not perceivable position changes once
 the view controller's view is not visible anymore but still has to move
 to the final center position.
 ````
 // determine the dismissed position depending on the slide in source
 // from (dism)  -->  to (pres)
 // +---------+       +---------+
 // |         |       |  y      |
 // |     +---+       | x+---+  |
 // |     |   |  ==>  |  |   |  |
 // |     +---+       |  +---+  |
 // +---------+       +---------+
 // Don't need to fully shift to the left.
 ````
 */
class SlideAnimationDriver: NSObject {
    let cls = "SlideAnimationDriver"
    let op: SlideOperation

    static func create(op: SlideOperation, config: SlidePresentationConfig) -> SlideAnimationDriver {
        return SlideAnimationDriver(op: op, config: config)
    }

    let config: SlidePresentationConfig

    // Store the transitioning context
    var trsCtx: UIViewControllerContextTransitioning?
    var duration: TimeInterval = 0.3
    private var animator: UIViewPropertyAnimator?
    var animationInProgress = false

    // start of the animation (presented)
    var viewStartFrame: CGRect = .zero
    // end of the animation (dismissed)
    var viewEndFrame: CGRect = .zero

    // presented frame
    var viewPresFrame: CGRect = .zero
    // dismissed frame
    var viewDismFrame: CGRect = .zero

    // DOC:
    // The animation driver shall be reusable. When the animator completed, animations and completions
    // are cleared. The configured flag tracks, whether a new configuration
    // (animation and completion) is needed.
    var configured: Bool = false

    init(op: SlideOperation, config: SlidePresentationConfig) {
        self.op = op
        self.config = config
        super.init()
        ad_log("\(self.cls): \(#function)")
    }

    // Use this method to access the animationDriver, that way the
    // instance can be private and the exposed interface is minimal.
    func interruptibleAnimator() -> UIViewImplicitlyAnimating? {
        return animator
    }

    func setup(using transitionContext: UIViewControllerContextTransitioning, duration: TimeInterval) {
        ad_log("\(self.cls): \(#function)")
        trsCtx = transitionContext
        self.duration = duration
    }

    /**
     Called from ``SlideAnimationController: interruptibleAnimator(using transitionContext:)``.
     Called from ``SlideAnimationController: animateTransition(using:)``
     Both call setup() before this and both do that for an interactive transition.
     Called from ``SlideAnimationDriver: start``.
     The caller of ``start`` calls setup() before it.
     */
    // FIXME: Check whether setup() and configureAnimations() can be merged to a single method.
    // FIXME: Since both calls are in interactive scenarios, check whether only one call is possible.
    // FIXME: In interactive mode, the first call is made in interruptibleAnimator and in non-interactive mode the first call is made in animateTransition - see if these can be the only calls.
    func configureAnimations() {
        ad_log("\(self.cls): \(#function)")
        guard let transitionContext = trsCtx else {
            ad_log("\(self.cls): \(#function): no transitionContext")
            return
        }
        if configured {
            ad_log("\(self.cls): \(#function): already configured - skipping")
            return
        }

        let key_vc_pstd: UITransitionContextViewControllerKey = op == .present ? .to : .from
        let key_vw_pstd: UITransitionContextViewKey = op == .present ? .to : .from
        guard let vc_pstd = transitionContext.viewController(forKey: key_vc_pstd) else {
            ad_log("\(self.cls): \(#function): no vc_pstd")
            return
        }
        guard let vw_pstd_0 = transitionContext.view(forKey: key_vw_pstd) else {
            ad_log("\(self.cls): \(#function): no vw_pstd")
            return
        }
        let vw_pstd: UIView
        if config.usePresentationContainerView {
            guard let _vw_pstd = vw_pstd_0.superview else {
                ad_log("\(self.cls): \(#function): vw_pstd has no superview")
                return
            }
            // vw_pstd = _vw_pstd
            vw_pstd = vw_pstd_0
        } else {
            vw_pstd = vw_pstd_0
        }
        let vw_con = transitionContext.containerView
        // use a snapshot view if needed:
        // guard let vw_snp = vc_to.view.snapshotView(afterScreenUpdates: true) else { return }

        // determine the start and end position
        let f_pres = transitionContext.finalFrame(for: vc_pstd)
        var f_dism = f_pres

        let conSize = transitionContext.containerView.frame.size
        switch config.effectiveSlideInOrigin {
        case .leading:  f_dism.origin.x = -f_pres.width
        case .trailing: f_dism.origin.x = conSize.width
        case .top:      f_dism.origin.y = -f_pres.height
        case .bottom:   fallthrough
        default:        f_dism.origin.y = conSize.height
        }

        // Remember the animation start and end frames for easier
        // calculations of percentage while the interactive transition
        // is in progress.
        viewStartFrame = op == .present ? f_dism : f_pres
        viewEndFrame   = op == .present ? f_pres : f_dism
        viewPresFrame  = f_pres
        viewDismFrame  = f_dism

        ad_log("\(self.cls): \(#function): calculated start/end frame: viewStartFrame=\(String(describing: self.viewStartFrame)) viewEndFrame=\(String(describing: self.viewEndFrame))")

        switch op {
        case .present:
            // Presentation extra: Add view to hiewarchy
            if config.usePresentationContainerView {

            } else {
                vw_con.addSubview(vw_pstd)
            }
            if config.cornerRadius > 0.0 {
                vc_pstd.view.layer.cornerRadius = config.cornerRadius
                vc_pstd.view.clipsToBounds = true
            }
        case .dismiss:
            // No extras at start of dismiss
            break
        }

        vw_pstd.frame = viewStartFrame

        // animate the change
        let dur = duration
        let anim = animator ?? UIViewPropertyAnimator(duration: dur, curve: .linear)
        anim.addAnimations({
            self.animationInProgress = true
            vw_pstd.frame = self.viewEndFrame
        })
        anim.addCompletion({ pos in
            let cancelled = transitionContext.transitionWasCancelled
            // when using a snapshot view, remove that and show the view controlle view
            let show = self.op == .present ? true : false
            if !cancelled {
                vw_pstd.isHidden = !show
                if self.op == .dismiss {
                    // vw_pstd.removeFromSuperview()
                }
            } else {
                vw_pstd.frame = self.viewStartFrame
            }
            self.animationInProgress = false
            self.configured = false
            ad_log("\(self.cls): \(#function): calling transitionContext.completeTransition(\(!cancelled)) - op:\(self.op)")
            transitionContext.completeTransition(!cancelled)
        })

        configured = true
        animator = anim
    }

    // FIXME: CHeck whether these can be deleted. See, if velocity when panning ends can be applied without these
    // DOC:
    // Because the animation controller implements interruptibleAnimator, the following
    // methods are not needed. UIKit will drive that on its own through the reference to
    // the UIViewPropertyAnimator provided with that method.
    /*
    func continueBackward() {
        guard let a = animator else { return }
        a.isReversed = true
        let fac = 1 - a.fractionComplete
        a.continueAnimation(withTimingParameters: nil, durationFactor: fac)
    }

    func continueForward() {
        guard let a = animator else { return }
        let fac = a.isReversed ? 1 - a.fractionComplete : a.fractionComplete
        a.continueAnimation(withTimingParameters: nil, durationFactor: fac)
    }

    func updateFractionComplete(_ percent: CGFloat) {
        guard let a = animator else { return }
        a.fractionComplete = percent
    }
     */

    /**
     Called in ``SlidePresentAnimationController``'s ``animateTransition()``.
     */
    // FIXME: check whether this can be merged with the calls to setup and configureAnimations - the startAnimation() call should be skipped in interactive scenarios however
    func start() {
        ad_log("\(self.cls): \(#function)")
        configureAnimations()
        guard let anim = animator else { return }
        anim.startAnimation()
    }

}

class SlideDismissAnimationDriver: SlideAnimationDriver {
    init(config: SlidePresentationConfig) {
        super.init(op: .dismiss, config: config)
    }
}

class SlidePresentAnimationDriver: SlideAnimationDriver {
    init(config: SlidePresentationConfig) {
        super.init(op: .present, config: config)
    }
}
