//
//  SlideUtil.swift
//  ADPresentationKit
//
//  Created by Schwarze on 22.05.22.
//

import UIKit

/**
 Helper methods for interactive transitions.
 */
class SlideUtil: NSObject {
    /**
     Returns the scalar translation in the axis matching the slide-in origin.
     */
    static func scalar(xlt: CGPoint, origin: SlidePresentationOrigin, op: SlideOperation) -> CGFloat {
        let vert = abs(xlt.y) > abs(xlt.x)
        let horz = abs(xlt.x) > abs(xlt.y)
        let rc: CGFloat
        switch origin {
        case .top:      rc = vert ?  xlt.y : 0.0
        case .leading:  rc = horz ?  xlt.x : 0.0
        case .trailing: rc = horz ? -xlt.x : 0.0
        case .auto: fallthrough
        case .none: fallthrough
        case .bottom:   rc = vert ? -xlt.y : 0.0
        }
        return op == .present ? rc : -rc
    }

    /**
     Returns true, if the direction of the translation matches the slide-in origin.
     */
    static func xlat(_ xlat: CGPoint, matches origin: SlidePresentationOrigin, op: SlideOperation) -> Bool {
        let scalar = scalar(xlt: xlat, origin: origin, op: op)
        return scalar > 0.0
    }

    /**
     Returns the percentage of the transition depending on the scalar translation value.

     Note that the "obvious formulas" to calculate the percentage are slightly different
     between present and dismiss, but with the inversion of signs eventually
     turn out to be the same calculations.
     */
    static func percentage(scalar: CGFloat, origin: SlidePresentationOrigin, vcFr: CGRect, conFr: CGRect, op: SlideOperation) -> CGFloat {
        var start = 0.0
        var end = 0.0
        var delta = 0.0

        switch origin {
        case .top:
            start = 0.0
            end = vcFr.maxY
            delta = (end - start)
        case .leading:
            start = 0.0
            end = vcFr.maxX
            delta = (end - start)
        case .trailing:
            start = conFr.maxX
            end = vcFr.minX
            delta = -(end - start)
        case .auto: fallthrough
        case .none: fallthrough
        case .bottom:
            start = conFr.maxY
            end = vcFr.minY
            delta = -(end - start)
        }

        let perc = scalar / delta
        // ad_log("\(self.cls): \(#function): ... \(scalar) --> \(start) -> \(end) : \(delta) -> \(perc)")

        return perc
    }

    /*
     Move from source spot

     (from dismiss:)
     The center of the presented view controller can be moved to the edge
     of the screen / window.
     +----------------------+
     |         ^            | top:   0 .. 100% = cy .. 0             (delta = cy)
     |    +----------+      |
     |    |    |     |      | lead:  0 .. 100% = cx .. 0             (delta = cx)
     |<---|----C-----|----->|
     |    |    |     |      | trail: 0 .. 100% = cx .. con_fr.width  (delta = con_fr.width - cx)
     |    +----------+      |
     |         v            | bot:   0 .. 100% = cy .. con_fr.height (delta = con_fr.height - cy)
     +----------------------+
     */
}
