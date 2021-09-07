//
//  Finger.swift
//  VideoChatApp
//
//  Created by Hongyu Lin on 2021/8/13.
//

import Foundation
import Vision
import simd


enum Finger: Hashable, CaseIterable {
    
    case thumb, index, middle, ring, little
    
    static func isExtended(tip: VNRecognizedPoint?, dip: VNRecognizedPoint?, pip: VNRecognizedPoint?, wrist: VNRecognizedPoint) -> Bool{
        guard let tip = tip,
              let pip = pip,
              let dip = dip
        else {
            return false
        }
        
        return tip.distance(wrist) > dip.distance(wrist) && tip.distance(wrist) > pip.distance(wrist) && dip.distance(wrist) > pip.distance(wrist)
    }
    
    
    static func isThumbUp(tip:VNRecognizedPoint?, ip: VNRecognizedPoint?, mp:VNRecognizedPoint?, cmc:VNRecognizedPoint?, indexMCP: VNRecognizedPoint?, littleMCP: VNRecognizedPoint?) -> Bool{
        guard let tip = tip,
              let ip = ip,
              let mp = mp,
              let cmc = cmc,
              let indexMCP = indexMCP,
              let littleMCP = littleMCP
              else {
            return false
        }
        let thumbIndexProduct = normalizedDotProduct(origin: mp.location, joints: (ip.location, indexMCP.location))
        
        return thumbIndexProduct < 0.65 &&
            tip.distance(cmc) > ip.distance(cmc) &&
            ip.distance(cmc) > mp.distance(cmc) && tip.distance(littleMCP) > indexMCP.distance(littleMCP)
    }
    
    static func getExtendedFingers(handLandMarks:[VNHumanHandPoseObservation.JointName:VNRecognizedPoint]) -> Set<Finger>{
        guard let wrist = handLandMarks[.wrist] else {
            return []
        }
        let fingers = Finger.allCases.filter { finger in
            switch finger{
                case .thumb:
                    return isThumbUp(tip: handLandMarks[.thumbTip], ip: handLandMarks[.thumbIP], mp: handLandMarks[.thumbMP], cmc: handLandMarks[.thumbCMC], indexMCP: handLandMarks[.indexMCP], littleMCP: handLandMarks[.littleMCP])
                case .index:
                    return isExtended(tip: handLandMarks[.indexTip]!,dip: handLandMarks[.indexDIP], pip: handLandMarks[.indexPIP]!, wrist: wrist)
                case .middle:
                    return isExtended(tip: handLandMarks[.middleTip]!,dip: handLandMarks[.middleDIP], pip: handLandMarks[.middlePIP]!, wrist: wrist)
                case .ring:
                    return isExtended(tip: handLandMarks[.ringTip],dip: handLandMarks[.ringDIP] ,pip: handLandMarks[.ringPIP], wrist: wrist)
                case .little:
                    return isExtended(tip: handLandMarks[.littleTip]!,dip: handLandMarks[.littleDIP] ,pip: handLandMarks[.littlePIP]!, wrist: wrist)
            }
            
        }
        return Set<Finger>(fingers)
    }
}

func normalizedDotProduct(origin: CGPoint, joints: (CGPoint, CGPoint)) -> Double {
  let origin = SIMD2(origin)
  return dot(
    normalize(SIMD2(joints.0) - origin),
    normalize(SIMD2(joints.1) - origin)
  )
}


extension SIMD2 where Scalar == CGFloat.NativeType {
  init(_ point: CGPoint) {
    self.init(x: point.x.native, y: point.y.native)
  }
}
