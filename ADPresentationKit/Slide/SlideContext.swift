//
//  SlideContext.swift
//  ADPresentationKit
//
//  Created by Schwarze on 27.05.22.
//

import UIKit

/**
 Holds common instances and state for the slide custom presentation.
 */
class SlideContext: NSObject {
    var presentAnimationController: SlidePresentAnimationController?
    var dismissAnimationController: SlideDismissAnimationController?
    var presentInteractionController: SlidePresentInteractionController?
    var dismissInteractionController: SlideDismissInteractionController?
    var presentAnimationDriver: SlidePresentAnimationDriver?
    var dismissAnimationDriver: SlideDismissAnimationDriver?
}
