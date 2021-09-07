//
//  Arbiter.swift
//  VideoChatApp
//
//  Created by Hongyu Lin on 2021/8/13.
//

import Foundation
import UIKit
import Vision


enum HandPose: String {
    case metal = "Rock On!"
    case peace = "Yeah"
    case pointing = "Pointing"
    case fist = "Punch you"
    case thumbUp = "Good"
    case five = "Hola"
    case callMe = "Call me"
    case suck = "Suck"
    case ok = "OK"
    case unsure = ""
}

final class MyModel{
    
    static func evaluateHandPose(from handLandMarks:[VNHumanHandPoseObservation.JointName: VNRecognizedPoint]) ->  HandPose{
        guard handLandMarks[.wrist] != nil else {
            return .unsure
        }
        
        switch Finger.getExtendedFingers(handLandMarks: handLandMarks){
        case [.little, .index]: return .metal
        case [.index, .middle]: return .peace
        case [.thumb]: return .thumbUp
        case[.thumb,.little]: return .callMe
        case Set(Finger.allCases): return .five
        case [.index]: return .pointing
        case [.middle]: return .suck
        case [.middle, .ring, .little]: return .ok
        case []: return .fist
        default:
            return .unsure
        }
    }
    
}
