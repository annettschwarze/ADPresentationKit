//
//  SlidePresentationManager.swift
//  ADPresentationKit
//
//  Created by Schwarze on 16.04.22.
//

import Foundation
import UIKit

/*
 TODO: add marker views for cancel indication? -> would need to change vc view for animation to a view-container view for animation
 TODO: add support for edge swipe gesture recognizers (UIScreenEdgePanGestureRecognizer)
 TODO: review the methods and vars in the UIPresentationController and check whether some details are helpful

 FIXME: Put the presented view controller's view into a container, which will be moved; this saves the view controller view from receiving layout calls after each frame change
 FIXME: Consider placing the view controller view into a special container for rounded corner and clips to bounds without modifying the view controller's view itself
 FIXME: panning the vc's view triggers a layout; find a way to prevent that, as no size change takes place
 FIXME: add option (1) to pan with single finger and (2) detect dismiss when pushing out of screen edge
 FIXME: check rotation during interactive or non-interactive transitions - any safe guards needed?
 FIXME: Read carefully and look into size adaptations: https://developer.apple.com/documentation/uikit/uipresentationcontroller
 */

// DOC:
// A block passed to the present interaction controller so the presentation can
// be started, when the gesture recognizer kicks in.
typealias SlidePresentationBegin = () -> ()

/** The main starting point to use a slide presentation.

 To set up a slide presentation, create an instance of the `SlidePresentationManager`
 and add it as a `transitioningDelegate` of the view controller, which is to
 be presented. Note that a strong reference to the manager instance should be
 kept in addition in order to prevent it from being deallocated before
 the animation happens.

 ````
 let pm = SlidePresentationManager()
 vc.modalPresentationStyle = .custom
 vc.pm = pm
 pm.config.layoutCompressed = isCompact
 pm.config.anchorHorizontal = .leading
 pm.config.anchorVertical = .top
 pm.config.slideInOrigin = .top
 pm.config.cornerRadius = 20.0
 vc.transitioningDelegate = pm
 present(vc, animated: true, completion: nil)
 ````

 - SeeAlso:
 ``SlidePresentationConfig``
 */
public class SlidePresentationManager: NSObject, UIViewControllerTransitioningDelegate {
    static let cls = "SlidePresentationManager"
    let cls = SlidePresentationManager.cls

    /** Adjust the properties of this config instance to modify behaviour of
     the slide presentation. */
    @objc public let config: SlidePresentationConfig = SlidePresentationConfig()
    let context: SlideContext = SlideContext()
    var presentationController: SlidePresentationController?
    
    // var presentInteractionController: SlidePresentInteractionController?

    // MARK: - Interactive Presentation Starter

    /**
     Prepare an interactive presentation for the given view.

     A gesture recognizer is installed in the given view. When gesture is
     recognized, which can start a presentation, the `beginHook` block is
     called. Put the presentation code into that block.

     ````
     self.slidePM = [[SlidePresentationManager alloc] init];
     self.slidePM.config.slideInOrigin = SlidePresentationOriginTop;
     self.slidePM.config.layoutCompressed = YES;
     [self.slidePM attachPresentInteraction:self.slidePresentView parentVC:self beginHook:^{
         FancyBoxViewController *vc = [[FancyBoxViewController alloc]
                initWithNibName:@"FancyBoxViewController" bundle:nil];
         vc.modalPresentationStyle = UIModalPresentationCustom;
         vc.transitioningDelegate = self.slidePM;
         [self presentViewController:vc animated:YES completion:^{
             NSLog(@"%s: FancyBox interactively presented - completion", __PRETTY_FUNCTION__);
         }];
     }];
     ````

     Currently only one attachment is supported. If multiple views shall be
     used to start a presentation, each one needs a separate instance of
     `SlidePresentationManager`.
     */
    @objc
    func attachPresentInteraction(_ view: UIView, beginHook: SlidePresentationBegin?) {
        guard context.presentInteractionController == nil else {
            ad_log("\(self.cls): \(#function): presentInteractionController already exists - not attaching")
            return
        }
        let pic = SlidePresentInteractionController(config: config)
        // Store the reference before calling attach, so it is already set in case it is queried:
        context.presentInteractionController = pic
        pic.attachTo(view: view, beginHook: { _ in
            beginHook?()
        })
    }

    // MARK: - UIViewControllerTransitioningDelegate: Presentation Controller

    /**
     Overridden
     */
    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        let ctrl = SlidePresentationController(presentedViewController: presented, presenting: presenting, config: config)
        ctrl.context = context
        presentationController = ctrl
        ad_log("\(self.cls): \(#function): ctrl=\(ctrl)")
        return ctrl
    }

    // MARK: - UIViewControllerTransitioningDelegate: Presentation Animation

    /**
     Implement this method, if a custom presentation animation shall be provided.
     If this method return `nil`, a standard animation is used by `UIKit`.
     */
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        ad_log("\(self.cls): \(#function): checking for interactive")

        let ad = SlidePresentAnimationDriver(config: config)
        context.presentAnimationDriver = ad

        let ctrl = SlidePresentAnimationController(config: config)
        ad_log("\(self.cls): \(#function): ctrl=\(ctrl)")
        ctrl.animationDriver = ad
        context.presentAnimationController = ctrl
        return ctrl
    }

    /**
     Implement this method to provide an interactive presentation.

     Note that `animator` is an instance of `SlidePresentAnimationController`.
     */
    public func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        ad_log("\(self.cls): \(#function)")
        // Only if an interaction has been set up and only if the presentation is in progress should
        // the interaction controller be returned.
        // (For an interactive presentation, the presentInteractionController always exists
        // and this is not sufficient for determining whether or not to return nil.)
        guard let pic = context.presentInteractionController, pic.interactionInProgress else {
            return nil
        }
        // Pass along the animation driver:
        pic.animationDriver = context.presentAnimationDriver
        return pic
    }

    // MARK: - UIViewControllerTransitioningDelegate: Dismissal Animation

    /**
     Implement this method to provide a custom dismiss animation.
     If this method returns `nil`, a standard animation is used by `UIKit`.
     */
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        ad_log("\(self.cls): \(#function): checking for interactive")

        let ad = SlideDismissAnimationDriver(config: config)
        context.dismissAnimationDriver = ad

        let ctrl = SlideDismissAnimationController(config: config)
        ad_log("\(self.cls): \(#function): ctrl=\(ctrl)")
        ctrl.animationDriver = ad
        context.dismissAnimationController = ctrl
        return ctrl
    }

    /**
     Implement this method to provide an interactive dismissal.

     Note that `animator` is an instance of `SlideDismissAnimationController`.
     */
    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        ad_log("\(self.cls): \(#function)")
        // An interactive dismiss requires, that the interaction controller exists already.
        // Also it should only be returned, if the interaction is actually in progress.
        guard let ctrl = context.dismissInteractionController, ctrl.interactionInProgress else {
            ad_log("\(self.cls): \(#function): dismiss not in progress, returning nil")
            return nil
        }
        ad_log("\(self.cls): \(#function): ctrl=\(ctrl)")
        // Pass along the animation driver:
        ctrl.animationDriver = context.dismissAnimationDriver
        return ctrl
    }

    // MARK: Runtime Layout Adjustments

    static func updateSize(vc: UIViewController, animated: Bool = true) {
        let presentationController = vc.presentationController

        presentationController?.containerView?.setNeedsLayout()
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: .allowUserInteraction, animations: {
                presentationController?.containerView?.layoutIfNeeded()
            }, completion: { finished in
                ad_log("\(Self.cls): \(#function): updateSize animation completed")
            })
        } else {
            presentationController?.containerView?.layoutIfNeeded()
        }
    }

}
