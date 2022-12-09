//
//  SlidePresentationPanning.swift
//  ADPresentationKit
//
//  Created by Schwarze on 13.05.22.
//

import UIKit

/**
 Provides two-finger-shifting of the view controller view.
 This is installed by the ``SlidePresentationController``.
 */
class SlidePresentationPanning: NSObject {
    let cls = "SlidePresentationPanning"
    let config: SlidePresentationConfig
    var pan: UIPanGestureRecognizer?
    var con_vw: UIView?

    init(config: SlidePresentationConfig) {
        self.config = config
        super.init()
    }

    func attachTo(vc: UIViewController, con_vw: UIView) {
        ad_log("\(self.cls): \(#function): attaching")
        guard pan == nil else {
            ad_log("\(self.cls): \(#function): panning already attached - skipping")
            return
        }
        let p = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        let num = config.panShiftTwoEnabled ? 2 : config.panShiftSingleEnabled ? 1 : 2
        p.minimumNumberOfTouches = num
        p.maximumNumberOfTouches = num
        vc.view.addGestureRecognizer(p)
        pan = p
        self.con_vw = con_vw
    }

    func detach() {
        ad_log("\(self.cls): \(#function): detaching")
        if let p = pan, let v = p.view {
            v.removeGestureRecognizer(p)
            pan = nil
        }
    }

    @objc func handlePan(_ gr: UIPanGestureRecognizer) {
        let xlt = gr.translation(in: gr.view)
        // Reset translation to have incremental shifts in each call:
        gr.setTranslation(.zero, in: gr.view)
        switch gr.state {
        case .began:
            fallthrough
        case .changed:
            guard let v = gr.view, let con_vw = con_vw else { return }
            // There is a holder view (superview of VC's view), which should be used for
            // the actual translation
            let vs: UIView
            let vw_move: UIView
            if config.usePresentationContainerView {
                guard let _vs = v.superview else { return }
                // vs = _vs
                // use the standard view for now:
                vs = v
                vw_move = _vs
            } else {
                vs = v
                vw_move = v
            }
            let vw_fr = vs.frame
            let vw_ctr = vs.center
            let con_fr = con_vw.frame
            // Determine the allowed region of the view controller's view:
            // let con_fr_ctr_allowed = allowedCenterArea(con_fr: con_fr, vw_fr: vw_fr)

            let inset_horz = config.layoutHorizontalGap
            let inset_vert = config.layoutVerticalGap
            let con_fr_allowed = con_fr.inset(by: UIEdgeInsets(top: inset_vert, left: inset_horz, bottom: inset_vert, right: inset_horz))

            // Determine new (translated) frame:
            var new_fr = vw_fr
            new_fr.origin.x += xlt.x
            new_fr.origin.y += xlt.y
            // var new_ctr = vw_ctr
            var new_ctr = vw_move.center
            new_ctr.x += xlt.x
            new_ctr.y += xlt.y
            // If new frame is not inside allowed region, don't translate
            let tmp_fr = con_fr_allowed.intersection(new_fr)
            if new_fr != tmp_fr {
                break
            }
            // Depending on the use of a container view, move the holder view, not the VC's view:
            // vs.frame = new_fr
            // vs.center = new_ctr
            vw_move.center = new_ctr

            // Determine the allowed center box - this is the allowed frame inset by half the width and height
            let con_ctr_allowed = con_fr_allowed.insetBy(dx: vw_fr.width / 2.0, dy: vw_fr.height / 2.0)
            // let con_ctr_allowed = con_fr_ctr_allowed
            // Determine the current center pos
            let ctr = CGPoint(x: new_fr.midX, y: new_fr.midY)
            let ctr_rel = CGPoint(
                x: (ctr.x - con_ctr_allowed.minX) / con_ctr_allowed.width,
                y: (ctr.y - con_ctr_allowed.minY) / con_ctr_allowed.height
            )
            config.relativePosition = ctr_rel
            ad_log("\(self.cls): \(#function): panning relPos=\(String(describing: ctr_rel))")

            break
        default:
            break
        }
    }

    func allowedCenterArea(con_fr: CGRect, vw_fr: CGRect) -> CGRect {
        let inset_horz = config.layoutHorizontalGap
        let inset_vert = config.layoutVerticalGap
        // let con_fr_allowed = con_fr.inset(by: UIEdgeInsets(top: inset_vert, left: inset_horz, bottom: inset_vert, right: inset_horz))
        let con_fr_allowed = con_fr.insetBy(dx: inset_horz, dy: inset_vert)
        let con_ctr_allowed = con_fr_allowed.insetBy(dx: vw_fr.width / 2.0, dy: vw_fr.height / 2.0)
        return con_ctr_allowed
    }

    func relativeCenterPos(con_ctr_allowed: CGRect, ctr: CGPoint) -> CGPoint {
        let ctr_rel = CGPoint(
            x: (ctr.x - con_ctr_allowed.minX) / con_ctr_allowed.width,
            y: (ctr.y - con_ctr_allowed.minY) / con_ctr_allowed.height
        )
        return ctr_rel
    }

    func smallestDirection(con_ctr: CGRect, ctr: CGPoint, vw_fr: CGRect) -> (CGFloat, SlidePresentationOrigin, CGPoint, CGFloat) {
        /*
           +-----------+
           |  +        |
           +-----------+
         ctr.x - fr.minX: <0 if outside
         fr.maxX - ctr.x: <0 if outside

                 +-------
           [___+_|_]  :
                 +-------
         ctr.x(+) at -midX is 100%, ctr.x at con_ctr.minX is 0%
         */
        let xlo = ctr.x - con_ctr.minX
        let xhi = con_ctr.maxX - ctr.x
        let ylo = ctr.y - con_ctr.minY
        let yhi = con_ctr.maxY - ctr.y
        var perc = 0.0
        var min = xlo
        var minOrigin : SlidePresentationOrigin = .leading
        var minCtr = ctr
        if xlo < 0 {
            minCtr.x = con_ctr.minX
            perc = (con_ctr.minX - ctr.x) / (vw_fr.midX + con_ctr.minX)
        }
        if xhi < min {
            min = xhi
            minOrigin = .trailing
            minCtr = ctr
            if min < 0 {
                minCtr.x = con_ctr.maxX
                perc = (ctr.x - con_ctr.maxX) / (vw_fr.midX + con_ctr.maxX)
            }
        }
        if ylo < min {
            min = ylo
            minOrigin = .top
            minCtr = ctr
            if min < 0 {
                minCtr.y = con_ctr.minY
                perc = (con_ctr.minY - ctr.y) / (vw_fr.midY + con_ctr.minY)
            }
        }
        if yhi < min {
            min = yhi
            minOrigin = .bottom
            minCtr = ctr
            if min < 0 {
                minCtr.y = con_ctr.maxY
                perc = (ctr.y - con_ctr.maxY) / (vw_fr.midY + con_ctr.maxY)
            }
        }
        return (min, minOrigin, minCtr, perc)
    }
}
