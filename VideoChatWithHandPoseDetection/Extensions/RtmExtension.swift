//
//  RtmExtension.swift
//  VideoChatWithHandPoseDetection
//
//  Created by Hongyu Lin on 2021/9/7.
//

import Foundation
import AgoraRtmKit

extension VideoChatViewController: AgoraRtmDelegate{
    
    func loginRtmSystem(){
        rtmKit.login(byToken: self.token!, user: String(self.uid!) , completion: nil)
    }
    
    func logoutRtmSystem(){
        rtmKit.logout(completion: nil)
    }
    
    func sendMessage(gifName:String){
        let message = AgoraRtmMessage(text: gifName)
        rtmKit.send(message, toPeer: String(self.peerID!), completion: nil)
    }
}
