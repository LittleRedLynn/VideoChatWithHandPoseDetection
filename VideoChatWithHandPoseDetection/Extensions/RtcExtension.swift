//
//  RtcExtension.swift
//  VideoChatWithHandPoseDetection
//
//  Created by Hongyu Lin on 2021/9/7.
//

import Foundation
import AgoraRtcKit

extension VideoChatViewController: AgoraRtcEngineDelegate{
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {

        var parent: UIView = remoteVideoView
        if let it = localVideoCanvas, let canvasView = it.view {
            if canvasView == parent {
                parent = localVideoView
            }
        }

        if remoteVideoCanvas != nil {
            return
        }

        let remoteCanvasView = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: parent.frame.size))
        remoteVideoCanvas = AgoraRtcVideoCanvas()
        remoteVideoCanvas!.view = view
        remoteVideoCanvas!.renderMode = .hidden
        remoteVideoCanvas!.uid = uid
        parent.insertSubview(remoteCanvasView, at: 0)
        agoraKit.setupRemoteVideo(remoteVideoCanvas!)
        
        updateNotificationLabel(with: " remote user \(uid) has joined in ")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        if let it = remoteVideoCanvas, it.uid == uid {
            let _ = removeFromParent(it)
            remoteVideoCanvas = nil
        }
        updateNotificationLabel(with: " remote user has left this channel ")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        
        updateNotificationLabel(with: " join successfully! ")
        
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didRejoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        
        updateNotificationLabel(with: " you rejoin the channel successfully! ")
        
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, lastmileQuality quality: AgoraNetworkQuality) {
        
        let networkQuality = quality.rawValue

        UIView.animate(withDuration: 2, delay: 0.1, options: .curveLinear, animations: {
            switch networkQuality {
            case 1,2:
                self.networkQualityIndicator.tintColor = #colorLiteral(red: 0.2745098174, green: 0.4862745106, blue: 0.1411764771, alpha: 1)
            case 3,4:
                self.networkQualityIndicator.tintColor = #colorLiteral(red: 0.7254902124, green: 0.4784313738, blue: 0.09803921729, alpha: 1)
            case 5,6:
                self.networkQualityIndicator.tintColor = #colorLiteral(red: 1, green: 0.1491314173, blue: 0, alpha: 1)
            default:
                self.networkQualityIndicator.tintColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0)
            }
            
            self.networkQualityIndicator.alpha = 1
            self.networkQualityIndicator.alpha = 0
        }, completion: nil)
        
    }
    
}
