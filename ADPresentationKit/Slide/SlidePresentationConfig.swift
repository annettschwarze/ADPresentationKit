//
//  SlidePresentationConfig.swift
//  ADPresentationKit
//
//  Created by Schwarze on 16.04.22.
//

import Foundation
import UIKit

public enum SlidePresentationHorizontalAnchor {
    case auto
    case none
    case leading
    case middle
    case trailing
}

public enum SlidePresentationVerticalAnchor {
    case auto
    case none
    case top
    case middle
    case bottom
}

/** The direction from which the view controller will slide in */
@objc
public enum SlidePresentationOrigin: Int {
    case auto
    case none
    case top
    case bottom
    case leading
    case trailing
    var debug: String {
        switch self {
        case .auto: return ".auto"
        case .none: return ".none"
        case .top: return ".top"
        case .bottom: return ".bottom"
        case .leading: return ".leading"
        case .trailing: return ".trailing"
        }
    }
}

public enum SlideOperation {
    case present
    case dismiss
}

@objc
public class SlidePresentationConfig: NSObject {
    // Duration for preentation and dismissal
    var duration: Double = 0.3
    // Install a backdrop
    public var backdrop: Bool = true
    // Background color for the vackdrop view
    public var backdropBackgroundColor: UIColor = UIColor.black.withAlphaComponent(0.4)
    // Backdrop tap dismisses
    public var backdropDismiss: Bool = true
    // Presented view controller has cornerRadius?
    public var cornerRadius: Double = 0.0
    // Like popup
    @objc public var layoutCompressed: Bool = false
    // Gaps around view coontroller to safe area
    public var layoutHorizontalGap: CGFloat = 40.0
    public var layoutVerticalGap: CGFloat = 40.0
    // Anchor the compact layout view controller to top/middle/bottm and leading/middle/trailing
    public var anchorHorizontal: SlidePresentationHorizontalAnchor = .auto
    public var anchorVertical: SlidePresentationVerticalAnchor = .auto
    // TODO: Draggable intervals
    public var keyboardAvoidance: Bool = false
    // From where to slide in, either automatically or interactively
    @objc public var slideInOrigin: SlidePresentationOrigin = .auto
    // Dynamic slide-in-origin, which may change during runtime and overrides the preset in that case
    var runtimeSlideInOrigin: SlidePresentationOrigin? = nil
    var effectiveSlideInOrigin: SlidePresentationOrigin {
        get {
            if let o = runtimeSlideInOrigin {
                return o
            } else {
                return slideInOrigin
            }
        }
    }
    // Interactive dismiss enabled or not
    public var interactiveDismissEnabled: Bool = true
    // Interactive present enabled or not
    public var interactivePresentEnabled: Bool = true
    // Drag the view controller with two fingers
    public var panShiftTwoEnabled: Bool = false
    /** Drag the view controller with a single finger, moving out of edge triggers dismiss.
     Note that this is mutually exclusive with interactive dismiss. If
     interactive dismiss is enabled, it takes priority. */
    public var panShiftSingleEnabled: Bool = false
    // Gap at border of srceen into which panning is forbidden
    // var panShiftInsets: CGFloat = 16.0

    // The relative position of the center
    var relativePosition: CGPoint?
    // Keyboard frame if it is shown
    var currentKeyboardFrame: CGRect?

    // Wrap the view controller's view in a container view to prevent layut
    // calls when the view controller's view is moved.
    var usePresentationContainerView: Bool = false

    public func resetRelativePosition() { relativePosition = nil }
}
