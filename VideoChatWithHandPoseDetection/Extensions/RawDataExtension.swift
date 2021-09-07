//
//  RawDataExtension.swift
//  VideoChatWithHandPoseDetection
//
//  Created by Hongyu Lin on 2021/9/7.
//

import Foundation
import AgoraRtcKit

extension VideoChatViewController: AgoraVideoDataPluginDelegate{
    
    /// Occurs each time the SDK receives a video frame captured by the local camera.
    /// After you successfully register the video frame observer, the SDK triggers this callback each time a video frame is received. In this callback, you can get the video data captured by the local camera. You can then pre-process the data according to your scenarios.
    /// After pre-processing, you can send the processed video data back to the SDK by setting the videoFrame parameter in this callback.
    func mediaDataPlugin(_ mediaDataPlugin: AgoraMediaDataPlugin, didCapturedVideoRawData videoRawData: AgoraVideoRawData) -> AgoraVideoRawData {
        self.calculateFingerTips(videoRawData: videoRawData, renderCanvas: self.localVideoCanvas!)
        return videoRawData
    }
    
    /// Occurs each time the SDK receives a video frame before sending to encoder
    /// After you successfully register the video frame observer, the SDK triggers this callback each time a video frame is going to be sent to encoder. In this callback, you can get the video data before it is sent to enoder. You can then pre-process the data according to your scenarios.
    /// After pre-processing, you can send the processed video data back to the SDK by setting the videoFrame parameter in this callback.
    func mediaDataPlugin(_ mediaDataPlugin: AgoraMediaDataPlugin, willPreEncode videoRawData: AgoraVideoRawData) -> AgoraVideoRawData {
        return videoRawData
    }
    
    /// Occurs each time the SDK receives a video frame sent by the remote user.
    ///After you successfully register the video frame observer and isMultipleChannelFrameWanted return false, the SDK triggers this callback each time a video frame is received. In this callback, you can get the video data sent by the remote user. You can then post-process the data according to your scenarios.
    ///After post-processing, you can send the processed data back to the SDK by setting the videoFrame parameter in this callback.
    func mediaDataPlugin(_ mediaDataPlugin: AgoraMediaDataPlugin, willRenderVideoRawData videoRawData: AgoraVideoRawData, ofUid uid: uint) -> AgoraVideoRawData {
        return videoRawData
    }
    
}

extension CVPixelBuffer{
    
    static func createFrom(_ data: AgoraVideoRawData) -> CVPixelBuffer?{
        
        let height = Int(data.height)
        let width = Int(data.width)
        let yBuffer = data.yBuffer!
        let uBuffer = data.uBuffer!
        let vBuffer = data.vBuffer!
        let yStride = Int(data.yStride)
        let uStride = Int(data.uStride)
        let vStride = Int(data.vStride)
        let format = kCVPixelFormatType_420YpCbCr8PlanarFullRange
        
        var pixelBuffer: CVPixelBuffer?
        
        CVPixelBufferCreate(kCFAllocatorDefault,
                            width,
                            height,
                            format,
                            nil,
                            &pixelBuffer)
        guard let pixelBuffer = pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let yPlaneAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
        let uPlaneAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
        let vPlaneAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 2)
        yPlaneAddress?.copyMemory(from: yBuffer, byteCount: yStride * height)
        uPlaneAddress?.copyMemory(from: uBuffer, byteCount: Int(Double(uStride * height) * 0.5))
        vPlaneAddress?.copyMemory(from: vBuffer, byteCount: Int(Double(vStride * height) * 0.5))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer
    }
}
