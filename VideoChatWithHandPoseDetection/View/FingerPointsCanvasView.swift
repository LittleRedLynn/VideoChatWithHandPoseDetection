//
//  FingerPointsCanvasView.swift
//  VideoChatApp
//
//  Created by Hongyu Lin on 2021/8/13.
//

import UIKit
import AVFoundation
class FingerPointsCanvasView: UIView {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    var points: [CGPoint]? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        if let fingerTips = self.points{
            
            for point in fingerTips{
                context.move(to: point)
                context.addArc(center: point, radius: 2, startAngle: 2 * .pi, endAngle: 0, clockwise: false)
            }
            context.setLineWidth(10)
            context.setStrokeColor(#colorLiteral(red: 0.8078431487, green: 0.02745098062, blue: 0.3333333433, alpha: 1))
            context.setLineCap(.round)
            context.setFlatness(0.9)
            context.strokePath()

        }

    }
}
