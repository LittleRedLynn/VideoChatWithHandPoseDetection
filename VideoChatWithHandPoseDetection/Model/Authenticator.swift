//
//  Authenticator.swift
//  VideoChatWithHandPoseDetection
//
//  Created by Hongyu Lin on 2021/9/7.
//

import Foundation
import Alamofire

final class Authorizer{
    
    let serverAddress = "107.191.61.35"
    let routeGetUserID = "/getUserID"
    let routeGetToken = "/getToken"
    let routeGetRtmToken = "/getRtmToken"
    
    static func getUserID(completionHandler: @escaping (String) -> Void){
        let url = "107.191.61.35/getUserID"
        AF.request(url, method: .get, parameters: nil, encoding: URLEncoding.default).responseJSON(completionHandler: { response in
            switch response.result {
            case .success:
                if let data = response.data {
                    completionHandler(String(data:data , encoding: String.Encoding.utf8)!)
                }
            case .failure(let error):
                print(error)
            }
            
        })
        
    }
    
    static func getToken(by channelName: String, for uid:String, completionHandler: @escaping (String) -> Void){
        let url = "107.191.61.35/getToken"
        let param: [String:Any] = ["channelName":channelName,"uid":uid, "expireTime":36000]
        AF.request(url, method: .get, parameters: param, encoding: URLEncoding.default).responseJSON(completionHandler: { response in
            switch response.result {
            case .success:
                if let data = response.data {
                    completionHandler(String(data:data , encoding: String.Encoding.utf8)!)
                }
            case .failure(let error):
                print(error)
            }
            
        })
        
    }
    
    static func getRtmToken(for uid:String, completionHandler: @escaping (String) -> Void){
        let url = "107.191.61.35/getRtmToken"
        let param: [String:Any] = ["uid":uid, "expireTime":36000]
        AF.request(url, method: .get, parameters: param, encoding: URLEncoding.default).responseJSON(completionHandler: { response in
            switch response.result {
            case .success:
                if let data = response.data {
                    completionHandler(String(data:data , encoding: String.Encoding.utf8)!)
                }
            case .failure(let error):
                print(error)
            }
            
        })
    }
    
}
