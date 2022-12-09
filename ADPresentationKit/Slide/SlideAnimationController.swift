//
//  SlideAnimationController.swift
//  ADPresentationKit
//
//  Created by Schwarze on 26.05.22.
//

import UIKit

/**
 Animates the transition and provide the interruptible animator if needed.
 Most of the actual work is delegated to ``SlideAnimationDriver``.
 */
class SlideAnimationController: NSObject, UIViewControllerAnimatedTransitioning {
    let cls = "SlideAnimationController"
    let op: SlideOperation
    let config: SlidePresentationConfig

    init(op: SlideOperation, config: SlidePresentationConfig) {
        self.op = op
        self.config = config
        super.init()
    }

    var animationDriver: SlideAnimationDriver?

    /**
     A duration of the animation must be provided by implementing this method.
     The actual duration is taken from the config instance.
     */
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        ad_log("\(self.cls): \(#function)")
        return config.duration
    }

    /**
     Implement this method to provide a non-interactive presentation animation.

     When ``SlidePresentationManager`` implements `interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning?`,
     and returns non-nil an interactive transition is assumed and this method is not called.

     (for dismiss)
     Note: `transitionContext` is for instance a `_UIViewControllerOneToOneTransitionContext`.
     Note: `[UIPresentationController runTransitionForCurrentState]_block_invoke` is on the call stack.
     */
    // FIXME: Go through the items in UIViewControllerContextTransitioning and check whether they are used properly here
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        ad_log("\(self.cls): \(#function)")

        guard let ad = animationDriver else {
            ad_log("\(self.cls): \(#function): error: no animation driver exists!")
            return
        }
        // The animation driver exists at this point
        let dur = self.transitionDuration(using: transitionContext)
        ad.setup(using: transitionContext, duration: dur)
        ad.configureAnimations()
        ad.start()
    }

    // UIKit:
    /// A conforming object implements this method if the transition it creates can
    /// be interrupted. For example, it could return an instance of a
    /// UIViewPropertyAnimator. It is expected that this method will return the same
    /// instance for the life of a transition.
    func interruptibleAnimator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        ad_log("\(self.cls): \(#function)")
        guard let ad = animationDriver else {
            ad_log("\(self.cls): \(#function): ERROR: animation driver does not exist")
            return UIViewPropertyAnimator()
        }
        ad.setup(using: transitionContext, duration: transitionDuration(using: transitionContext))
        ad.configureAnimations() // (This creates the interruptible animator instance)
        guard let ia = animationDriver?.interruptibleAnimator() else {
            ad_log("\(self.cls): \(#function): CRITICAL ERROR: An interruptible animator should exist but does not. Returning a dummy animator.")
            return UIViewPropertyAnimator()
        }
        ad_log("\(self.cls): \(#function): returning proper interruptible animator instance")
        return ia
    }

    // UIKit:
    // This is a convenience and if implemented will be invoked by the system when the transition context's completeTransition: method is invoked.
    /*
    func animationEnded(_ transitionCompleted: Bool) {
    }
     */
}

class SlideDismissAnimationController: SlideAnimationController {
    init(config: SlidePresentationConfig) {
        super.init(op: .dismiss, config: config)
    }
}

class SlidePresentAnimationController: SlideAnimationController {
    init(config: SlidePresentationConfig) {
        super.init(op: .present, config: config)
    }
}
