//
//  ViewController.swift
//  VideoChatWithHandPoseDetection
//
//  Created by Hongyu Lin on 2021/9/7.
//

//
//  ViewController.swift
//  VideoChatApp
//
//  Created by Hongyu Lin on 2021/8/10.
//

import UIKit
import AgoraRtcKit
import Vision
import AVFoundation
import Alamofire
import Gifu
import AgoraRtmKit

class VideoChatViewController: UIViewController{
    
    var agoraKit: AgoraRtcEngineKit!
    
    var rtmKit: AgoraRtmKit!
    
    var audioPlayer: AVAudioPlayer?
    
    let appID = "ec96415b6bae4f21b1af86ea3f804da5"
    
    let appCertificate = "c9361c398e6849a9bbdb451e2a158cfb"
    
    var token: String?
    
    var rtmToken: String?
    
    let channelName: String = "myChannel"
    
    var uid: Int?
    
    var peerID: Int?
    
    var isInChannel: Bool = false
    
    var reconnectionPatience: Int = 5
    
    var memoryDeviceOrientation: UIDeviceOrientation = .portrait
    
    @IBOutlet weak var localVideoView: UIView!
    
    @IBOutlet weak var remoteVideoView: UIView!
    
    @IBOutlet weak var remoteVideoViewMutedIndicator: UIImageView!
    
    @IBOutlet weak var localVideoViewMutedIndicator: UIImageView!
    
    @IBOutlet weak var localVideoViewBackground: UIImageView!
    
    @IBOutlet weak var callButton: UIButton!
    
    @IBOutlet weak var micButton: UIButton!
    
    @IBOutlet weak var convertButton: UIButton!
    
    @IBOutlet weak var localFingerPointsCanvasView: FingerPointsCanvasView?
    
    @IBOutlet weak var remoteFingerPointsCanvasView: FingerPointsCanvasView?
    
    @IBOutlet weak var stackView: UIStackView!
    
    @IBOutlet weak var networkQualityIndicator: UIButton!
    
    @IBOutlet weak var notificationLabel: UILabel!
    
    var localVideoCanvas: AgoraRtcVideoCanvas?
    
    var remoteVideoCanvas: AgoraRtcVideoCanvas?
    
    var agoraMediaDataPlugin: AgoraMediaDataPlugin?
    
    private var isConnectedToInternet: Bool{
        return NetworkReachabilityManager()?.isReachable ?? false
    }

    private let handPoseRequest: VNDetectHumanHandPoseRequest = {
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 2
        return request
    }()
    
    private var accumulatedHandLandMarks: [[VNHumanHandPoseObservation.JointName:VNRecognizedPoint]] = []
    
    
    var isCalling: Bool = false{
        didSet{
            if isCalling{
                localVideoViewBackground.isHidden = true
                localVideoViewMutedIndicator.isHidden = true
                setUpLocalVideo()
                joinChannel()
                let hangUpImage = UIImage(named: "end")
                let hangUpImagePressed = UIImage(named: "end_pressed")
                callButton.setImage(hangUpImage, for: .normal)
                callButton.setImage(hangUpImagePressed, for: .selected)
                
                
            }else{
                
                leaveChannel()
                localVideoViewBackground.isHidden = false
                localVideoViewMutedIndicator.isHidden = false
                remoteVideoViewMutedIndicator.isHidden = false
                let _ = removeFromParent(localVideoCanvas)
                localVideoCanvas = nil
                let _ = removeFromParent(remoteVideoCanvas)
                remoteVideoCanvas = nil
                let callImage = UIImage(named: "call")
                let callImagePressed = UIImage(named: "call_pressed")
                callButton.setImage(callImage, for: .normal)
                callButton.setImage(callImagePressed, for: .selected)
                let micImage = UIImage(named: "mic")
                let micImagePressed = UIImage(named: "mic_pressed")
                micButton.setImage(micImage, for: .normal)
                micButton.setImage(micImagePressed, for: .selected)
                self.localFingerPointsCanvasView?.points = []
                self.remoteFingerPointsCanvasView?.points = []
            }
        }
    }
    
    var isMuted: Bool = false{
        didSet{
            agoraKit.muteLocalAudioStream(isMuted)
            if isMuted{
                let mutedImage = UIImage(named: "mute")
                let mutedImagePressed = UIImage(named: "mute_pressed")
                micButton.setImage(mutedImage, for: .normal)
                micButton.setImage(mutedImagePressed, for: .selected)
            }else{
                let micImage = UIImage(named: "mic")
                let micImagePressed = UIImage(named: "mic_pressed")
                micButton.setImage(micImage, for: .normal)
                micButton.setImage(micImagePressed, for: .selected)
            }
        }
    }
    
    var isConverted: Bool = false{
        didSet{
            agoraKit.switchCamera()
        }
    }
    
    lazy var gifImageView: GIFImageView = {
        let gifView = GIFImageView()
        gifView.contentMode = .scaleAspectFit
        return gifView
    }()
    
    // MARK: - Draw Finger Points
        
    func processPoints(_ fingerTips: [CGPoint], _ handLandMarks:[VNHumanHandPoseObservation.JointName:VNRecognizedPoint], _ canvasView:FingerPointsCanvasView, _ frameWidth: Double, _ frameHeight: Double){
        var convertedPoints:[CGPoint] = []
        var k1:Double!
        var k2:Double!
        let currentDeviceOrientation = UIDevice.current.orientation
        var flag:Int = 0
        let canvasWidth = Double(canvasView.frame.width)
        let canvasHeight = Double(canvasView.frame.height)
        var pixelBufferWidth = frameWidth
        var pixelBufferHeight = frameHeight
        /**
        .hidden的渲染模式，其实只有两种填充的可能性，一种是pixelbuffer的上下两边超出canvasView而被裁剪，一种是pixelbuffer的左右两边超出canvasView而被裁剪。
         如何判断当前的pixelBuffer与canvasView是上下裁剪还是左右裁剪呢？只用判断pixelBuffer的宽高之比和canvasView的宽高之比的大小关系就可以了，如果pixelBuffer的宽高之比大于canvasView的宽高之比，那么就应该应用左右裁剪，反之，则应用上下裁剪
         
         iOS的相机拍摄出的图像是横过来的，是以landscapeRight的方向传到Session，所以这就是为什么我们在将pixelBuffer传入Vision的时候要进行旋转的原因
         而pixelBuffer的宽和高是一个常量，并不会随着我们对它的旋转而发生变化，但是pixelBuffer在Render的时候，确实是会进行旋转的。
         对于Portrait 肯定要向左旋转90度，而Portrait Upside Down则是向右旋转90度；对于Landscape Right，不用做任何变换，而对于Landscape Left，则需要上下倒置
         这就导致在Portrait和Portrait Upside Down这种方向下，PixelBuffer的宽高需要进行互换，因为无论是我们传入Vision的时候，还是进行Render的时候，都是对它进行了一个旋转，不然画面不会是正的，宽高互换之后，再进行上下裁剪和左右裁剪的判断
         而对于Landscape的两种情况，pixelBuffer的宽高则不需要进行互换，虽然Landscape Left需要进行倒置转换，但是我们通过Vision求出来的坐标是倒置后的图片上的坐标，同时当前Render的画面，也是已经进行倒置转换之后的画面了，所以同样不需要做任何转变。
         
         */
        if currentDeviceOrientation == .landscapeLeft || currentDeviceOrientation == .landscapeRight{
            if pixelBufferWidth / pixelBufferHeight >= canvasWidth / canvasHeight{
                flag = 1
            }else{
                flag = 0
            }
        }else if currentDeviceOrientation == .portrait || currentDeviceOrientation == .portraitUpsideDown{
            pixelBufferWidth = frameHeight
            pixelBufferHeight = frameWidth
            if pixelBufferWidth / pixelBufferHeight >= canvasWidth / canvasHeight{
                flag = 1
            }else{
                flag = 0
            }
        }else{
            if memoryDeviceOrientation == .landscapeLeft || memoryDeviceOrientation == .landscapeRight{
                if pixelBufferWidth / pixelBufferHeight >= canvasWidth / canvasHeight{
                    flag = 1
                }else{
                    flag = 0
                }
            }else if memoryDeviceOrientation == .portrait || memoryDeviceOrientation == .portraitUpsideDown{
                pixelBufferWidth = frameHeight
                pixelBufferHeight = frameWidth
                if pixelBufferWidth / pixelBufferHeight >= canvasWidth / canvasHeight{
                    flag = 1
                }else{
                    flag = 0
                }
            }
        }


        
        for relativePointInPixelBuffer in fingerTips {
            let xr = Double(relativePointInPixelBuffer.x)
            let yr = Double(relativePointInPixelBuffer.y)
            
            
            if flag == 0{
                // 上下裁剪
                
                k1 = pixelBufferHeight / pixelBufferWidth
                k2 = canvasHeight / canvasWidth
                let a = (k1 / k2)
                let b = (k1 - k2)/(2 * k1)

                let yrv = a * (yr - b)
                let absX = CGFloat(xr * canvasWidth)
                let absY = CGFloat(yrv * canvasHeight)
                convertedPoints.append(CGPoint(x: absX, y: absY))
            }else{
                // 左右裁剪

                k1 = pixelBufferWidth / pixelBufferHeight
                k2 = canvasWidth / canvasHeight
                
                let a = (k1 / k2)
                let b = (k1 - k2)/(2 * k1)
                let xrv = a * (xr - b)

                let absX = CGFloat(xrv * canvasWidth)
                let absY = CGFloat(yr * canvasHeight)
                convertedPoints.append(CGPoint(x: absX, y: absY))
                
            }
            
        }
        
        if convertedPoints.count > 0{
            canvasView.points = convertedPoints
        }
        else{
            canvasView.points = nil
        }

        self.accumulatedHandLandMarks.append(handLandMarks)
        if self.accumulatedHandLandMarks.count == 30{
            
            if self.peerID != nil{
                showHandPoseInEmojiLabel(handLandMarksBunch: self.accumulatedHandLandMarks)
            }
            self.accumulatedHandLandMarks.removeAll()
        }
    }
    
    // MARK: - GIF Image View Functions
    
    func updateGifImageViewAnimating(with gifName: String){
        self.gifImageView.animate(withGIFNamed: gifName)
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5){
            self.gifImageView.alpha = 1.0
            self.playCustomSound(with: gifName)
            
        }
        DispatchQueue.main.asyncAfter(deadline: .now()+2){
            if self.gifImageView.isAnimatingGIF{
                self.gifImageView.stopAnimatingGIF()
                self.gifImageView.alpha = 0.0

            }
        }
    }
    
    func setUpGifView(){
        gifImageView.translatesAutoresizingMaskIntoConstraints = false
        self.remoteVideoView.addSubview(gifImageView)
        gifImageView.centerXAnchor.constraint(equalTo: remoteVideoView.centerXAnchor).isActive = true
        gifImageView.centerYAnchor.constraint(equalTo: remoteVideoView.centerYAnchor).isActive = true
        let minBoundOfSuperview = min(self.remoteVideoView.frame.height, self.remoteVideoView.frame.width)
        gifImageView.heightAnchor.constraint(equalToConstant: 0.25 * minBoundOfSuperview).isActive = true
        gifImageView.widthAnchor.constraint(equalToConstant: 0.25 * minBoundOfSuperview).isActive = true
//        let gifHeightBound = gifImageView.heightAnchor.const
        
    }
    
    func updateGifViewConstraint(){
        gifImageView.translatesAutoresizingMaskIntoConstraints = false
        let minBoundOfSuperview = min(self.remoteVideoView.frame.height, self.remoteVideoView.frame.width)
        gifImageView.removeConstraints(gifImageView.constraints)
        gifImageView.heightAnchor.constraint(equalToConstant: 0.25 * minBoundOfSuperview).isActive = true
        gifImageView.widthAnchor.constraint(equalToConstant: 0.25 * minBoundOfSuperview).isActive = true
        gifImageView.centerXAnchor.constraint(equalTo: remoteVideoView.centerXAnchor).isActive = true
        gifImageView.centerYAnchor.constraint(equalTo: remoteVideoView.centerYAnchor).isActive = true
    }
    
    
    func showHandPoseInEmojiLabel(handLandMarksBunch:[[VNHumanHandPoseObservation.JointName:VNRecognizedPoint]]){
        var emojiStringFreq : [String:Int] = [:]
        for handLandMarks in handLandMarksBunch{
            let emojiString = MyModel.evaluateHandPose(from: handLandMarks).rawValue
            if let _ = emojiStringFreq[emojiString]{
                emojiStringFreq[emojiString]! += 1
            }else{
                emojiStringFreq.updateValue(1, forKey: emojiString)
            }
        }
        print(emojiStringFreq)
        let emojiStringWithMaxFreq = emojiStringFreq.max(){ a, b in
            a.value < b.value
        }
        if let maxItem = emojiStringWithMaxFreq{
            if maxItem.value < 21{
                return
            }
        }else{
            return
        }
        
        
        if self.gifImageView.isAnimatingGIF || self.gifImageView.isAnimating{
            return
        }
        switch emojiStringWithMaxFreq?.key {
        case "Rock On!":
            self.sendMessage(gifName: "rockon")
            updateGifImageViewAnimating(with: "rockon")

        case "Yeah":
            self.sendMessage(gifName: "peace")
            updateGifImageViewAnimating(with: "peace")
            
        case "Punch you":
            self.sendMessage(gifName: "punchyou")
            updateGifImageViewAnimating(with: "punchyou")
            
        case "Good":
            self.sendMessage(gifName: "thumbup")
            updateGifImageViewAnimating(with: "thumbup")
            
        case "Hola":
            self.sendMessage(gifName: "hola")
            updateGifImageViewAnimating(with: "hola")
            
        case "Suck":
            self.sendMessage(gifName: "suck")
            updateGifImageViewAnimating(with: "suck")
        
        case "OK":
            self.sendMessage(gifName: "ok")
            updateGifImageViewAnimating(with: "ok")
            
        default:
            break
        }
    }
    
    // MARK: - Custom Sound Functions
    
    func playCustomSound(with gifName:String){
        let path = Bundle.main.path(forResource: gifName, ofType: "wav")
        
        let soundPathURL = URL(fileURLWithPath: path!)
        
        do{
            audioPlayer = try AVAudioPlayer(contentsOf: soundPathURL)
            audioPlayer?.play()
        }catch{
            print("play sound failed")
        }
        
        
    }
    
    // MARK: - View Controller Life Cycle
    

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.bringSubviewToFront(networkQualityIndicator)
        self.view.bringSubviewToFront(stackView)
        
        initializeAgoraEngine()
        setUpVideo()

        let label = UILabel(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: stackView.frame.size))
        notificationLabel = label
        remoteVideoView.insertSubview(notificationLabel, at: remoteVideoView.subviews.count)
        notificationLabel.translatesAutoresizingMaskIntoConstraints = false

        notificationLabel.heightAnchor.constraint(equalTo: stackView.heightAnchor, multiplier: 0.5, constant: 0).isActive = true
        notificationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        stackView.topAnchor.constraint(equalTo: notificationLabel.bottomAnchor, constant: 80).isActive = true
        notificationLabel.layer.masksToBounds = true
        notificationLabel.layer.cornerRadius = 10
        notificationLabel.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        notificationLabel.alpha = 0
        notificationLabel.textAlignment = .center
        networkQualityIndicator.alpha = 0
        updateTokenAndUserID()
        setUpGifView()
        
        giveSmoothyBorder(for: localVideoView)
        giveSmoothyBorder(for: localVideoViewBackground!)
        giveSmoothyBorder(for: localFingerPointsCanvasView!)
        
        updateMutedIndicatorConstraint(indicatorView: localVideoViewMutedIndicator)
        updateMutedIndicatorConstraint(indicatorView: remoteVideoViewMutedIndicator)
        
    }
    

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updateGifViewConstraint()
        updateMutedIndicatorConstraint(indicatorView: localVideoViewMutedIndicator)
        updateMutedIndicatorConstraint(indicatorView: remoteVideoViewMutedIndicator)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        AgoraRtcEngineKit.destroy()
    }
    

    // MARK: - Agora RTC Functions
    
    func initializeAgoraEngine(){
        self.agoraKit = AgoraRtcEngineKit.sharedEngine(withAppId: self.appID, delegate: self)
        self.rtmKit = AgoraRtmKit.init(appId: self.appID, delegate: self)
    }
    
    func setUpVideo(){
        
        let _ = agoraKit.enableVideo()
        agoraKit.setVideoEncoderConfiguration(AgoraVideoEncoderConfiguration(size: AgoraVideoDimension640x360, frameRate: .fps30, bitrate: AgoraVideoBitrateStandard, orientationMode: .adaptative))
    }
    
    func joinChannel(){
        agoraKit.setDefaultAudioRouteToSpeakerphone(true)
        if let token = self.token, let uid = self.uid{
            let info = agoraKit.joinChannel(byToken: token , channelId: self.channelName, info: nil, uid: UInt(uid), joinSuccess: nil)
            if info < 0{
                localUserJoinFailed(status: Int(info))
                self.isInChannel = false
            }
        }else{
            self.isInChannel = false
            localUserJoinFailed(status: -8)
        }
        
        UIApplication.shared.isIdleTimerDisabled = true
        agoraMediaDataPlugin = AgoraMediaDataPlugin(agoraKit: agoraKit)
        let videoType:ObserverVideoType = ObserverVideoType(rawValue: ObserverVideoType.captureVideo.rawValue | ObserverVideoType.renderVideo.rawValue | ObserverVideoType.preEncodeVideo.rawValue)
        agoraMediaDataPlugin?.registerVideoRawDataObserver(videoType)
        agoraMediaDataPlugin?.videoDelegate = self
        
        self.loginRtmSystem()
        
        
    }
    
    func leaveChannel(){
        if !self.isInChannel{
            return
        }
        agoraKit.leaveChannel(nil)
        UIApplication.shared.isIdleTimerDisabled = false
        let alert = UIAlertController(title: "Notification", message: "You have already left this video chat room", preferredStyle: .alert)
        let alertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(alertAction)
        present(alert, animated: true, completion: nil)
        agoraKit.stopPreview()
        
        self.logoutRtmSystem()
        self.peerID = nil
        
    }
    
    func setUpLocalVideo(){
        let canvasView = UIView(frame: CGRect(origin: CGPoint(x: 0, y: 0), size: localVideoView.frame.size))
        
        localVideoCanvas = AgoraRtcVideoCanvas()
        localVideoCanvas!.view = canvasView
        localVideoCanvas!.renderMode = .hidden
        localVideoCanvas!.uid = 0
        localVideoCanvas!.view!.translatesAutoresizingMaskIntoConstraints = false
        localVideoView.insertSubview(localVideoCanvas!.view!, at: 0)

        localVideoCanvas!.view!.widthAnchor.constraint(equalTo: localVideoView.widthAnchor).isActive=true
        localVideoCanvas!.view!.heightAnchor.constraint(equalTo: localVideoView.heightAnchor).isActive=true
        localVideoCanvas!.view!.centerXAnchor.constraint(equalTo: localVideoView.centerXAnchor).isActive=true
        localVideoCanvas!.view!.centerYAnchor.constraint(equalTo: localVideoView.centerYAnchor).isActive=true
        
        agoraKit.setupLocalVideo(localVideoCanvas)
        agoraKit.startPreview()
    }
    
    
    
    // MARK: - UI Actions
    
    @IBAction func callButtonClicked(_ sender: UIButton) {
        if (isCalling == false && isConnectedToInternet) || isCalling == true{
            
            if self.token != nil && self.uid != nil{
                isCalling.toggle()
            }else{
                updateTokenAndUserID()
                localUserJoinFailed(status: -8)
            }
            
        }else{
            localUserJoinFailed(status: -1)
        }
        
    }
    
    
    @IBAction func micButtonClicked(_ sender: UIButton) {
        isMuted.toggle()
    }
    
    
    @IBAction func convertButtonClicked(_ sender: UIButton) {
        isConverted.toggle()
    }
    
    
    @IBAction func localVideoViewClicked(_ sender: UITapGestureRecognizer?){
            switchView(localVideoCanvas)
            switchView(remoteVideoCanvas)

    }
    
    @IBAction func handlePan(_ gesture: UIPanGestureRecognizer) {
      
        let translation = gesture.translation(in: view)

        
        guard let gestureView = gesture.view, let parentView = gesture.view?.superview else {
            return
        }
        
        var updatedX: CGFloat!
        var updatedY: CGFloat!
        
//        let paddingHeight = parentView.safeAreaInsets.bottom + parentView.safeAreaInsets.top
        let safeAreaHeight = parentView.safeAreaLayoutGuide.layoutFrame.height
        
        if gestureView.center.x + translation.x >= 0.5 * gestureView.frame.width && gestureView.center.x + translation.x <= self.view.frame.width - 0.5 * gestureView.frame.width{
            updatedX = gestureView.center.x + translation.x
        }else if gestureView.center.x + translation.x < 0.5 * gestureView.frame.width{
            updatedX = 0.5 * gestureView.frame.width
        }else if gestureView.center.x + translation.x > self.view.frame.width - 0.5 * gestureView.frame.width{
            updatedX = self.view.frame.width - 0.5 * gestureView.frame.width
        }else{
            updatedX = gestureView.center.x
        }
        
        
        if gestureView.center.y + translation.y >= 0.5 * gestureView.frame.height && gestureView.center.y + translation.y <= safeAreaHeight - 0.5 * gestureView.frame.height{
            updatedY = gestureView.center.y + translation.y
        }else if gestureView.center.y + translation.y < 0.5 * gestureView.frame.height{
            updatedY = 0.5 * gestureView.frame.height
        }else if gestureView.center.y + translation.y > safeAreaHeight - 0.5 * gestureView.frame.height{
            updatedY = safeAreaHeight - 0.5 * gestureView.frame.height
        }else{
            updatedY = gestureView.center.y
        }

        gestureView.center = CGPoint(
            x: updatedX,
            y: updatedY
        )
        
        if gesture.state.rawValue == 3{
            let leftHorizontalSpace = gestureView.center.x - 0.5 * gestureView.frame.width
            let rightHorizontalSpace = self.view.frame.width - (gestureView.center.x + 0.5 * gestureView.frame.width)
            let upVerticalSpace = gestureView.center.y - 0.5 * gestureView.frame.height
            let downVerticalSpace = safeAreaHeight - (gestureView.center.y + 0.5 * gestureView.frame.height)
            if leftHorizontalSpace <= 30{
                gestureView.center = CGPoint(
                    x: gestureView.center.x - leftHorizontalSpace,
                    y: gestureView.center.y
                )
            }else if rightHorizontalSpace <= 30{
                gestureView.center = CGPoint(
                    x: gestureView.center.x + rightHorizontalSpace,
                    y: gestureView.center.y
                )
            }
    
            if upVerticalSpace <= 30{
                gestureView.center = CGPoint(
                    x: gestureView.center.x,
                    y: gestureView.center.y - upVerticalSpace
                )
            }else if downVerticalSpace <= 30{
                gestureView.center = CGPoint(
                    x: gestureView.center.x,
                    y: gestureView.center.y + downVerticalSpace
                )
            }
            
        }
      
        gesture.setTranslation(.zero, in: view)
    }

    
    

    
    // MARK: - Logic Control Functions
    
    func updateMutedIndicatorConstraint(indicatorView: UIImageView){
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        indicatorView.removeConstraints(indicatorView.constraints)
        guard let parentView = indicatorView.superview else { return }
        let minBoundOfSuperview = min(parentView.frame.width,  parentView.frame.height)

        indicatorView.centerXAnchor.constraint(equalTo: parentView.centerXAnchor).isActive = true
        indicatorView.centerYAnchor.constraint(equalTo: parentView.centerYAnchor).isActive = true
        indicatorView.widthAnchor.constraint(equalToConstant: 0.25 * minBoundOfSuperview).isActive = true
        indicatorView.heightAnchor.constraint(equalToConstant: 0.25 * minBoundOfSuperview).isActive = true
    }
    
    func removeFromParent(_ canvas: AgoraRtcVideoCanvas?) -> UIView?{
        if let it = canvas, let canvasView = it.view{
            if let parent = canvasView.superview{
                canvasView.removeFromSuperview()
                return parent
            }
        }
        return nil
    }
    
    func switchView(_ canvas:AgoraRtcVideoCanvas?){
        if let parent = removeFromParent(canvas){
            if parent == localVideoView{
//                canvas!.view!.frame.size = remoteVideoView.frame.size
                canvas?.view?.translatesAutoresizingMaskIntoConstraints = false
                remoteVideoView.insertSubview(canvas!.view!, at: 0)
                canvas!.view!.widthAnchor.constraint(equalTo: remoteVideoView.widthAnchor).isActive=true
                canvas!.view!.heightAnchor.constraint(equalTo: remoteVideoView.heightAnchor).isActive=true
                canvas!.view!.centerXAnchor.constraint(equalTo: remoteVideoView.centerXAnchor).isActive=true
                canvas!.view!.centerYAnchor.constraint(equalTo: remoteVideoView.centerYAnchor).isActive=true

                remoteVideoViewMutedIndicator.isHidden = true
                if remoteVideoCanvas == nil{
                    // only the local user joined the channel
                    localVideoViewBackground.isHidden = false
                    localVideoViewMutedIndicator.isHidden = false
                }

            }else if parent == remoteVideoView{
                canvas!.view!.frame.size = localVideoView.frame.size
                canvas?.view?.translatesAutoresizingMaskIntoConstraints = false
                localVideoView.insertSubview(canvas!.view!, at: 0)
                canvas!.view!.widthAnchor.constraint(equalTo: localVideoView.widthAnchor).isActive=true
                canvas!.view!.heightAnchor.constraint(equalTo: localVideoView.heightAnchor).isActive=true
                canvas!.view!.centerXAnchor.constraint(equalTo: localVideoView.centerXAnchor).isActive=true
                canvas!.view!.centerYAnchor.constraint(equalTo: localVideoView.centerYAnchor).isActive=true

                localVideoViewBackground.isHidden = true
                localVideoViewMutedIndicator.isHidden = true
                if remoteVideoCanvas == nil{
                    // only the local user joined the channel
                    remoteVideoViewMutedIndicator.isHidden = false
                }
            }
        }
    }
    
    
    func localUserJoinFailed(status:Int){

        var errorInfo: String = ""
        switch status {
        case -1:
            errorInfo = "no Internet"
        case -2:
            errorInfo = "invalid parameter"
        case -3:
            errorInfo = "sdk initial failed"
        case -5:
            errorInfo = "request rejected"
        case -7:
            errorInfo = "sdk is not initialized"
        case -8:
            errorInfo = "authorization request time out"
        default:
            errorInfo = "unknown error"
        }
        updateNotificationLabel(with: " Join failed! Error:\(errorInfo) ")
    }
    
    
    func updateTokenAndUserID(){
        Authorizer.getUserID{ uidResult in
            self.uid = Int(uidResult)
            print("uid assigned successfully! your uid is \(uidResult)")
            Authorizer.getToken(by: self.channelName, for: String(self.uid!)){ tokenResult in
                self.token = tokenResult
                print("token assigned successfully!")
            }
            
            Authorizer.getRtmToken(for: String(self.uid!), completionHandler: { tokenResult in
                self.rtmToken = tokenResult
                print("rtm token assigned successfully")
                
            })
        }
    }
    

    
    func updateNotificationLabel(with text: String){
        if self.notificationLabel.alpha > 0{
            self.notificationLabel.alpha = 0
        }
        
        self.notificationLabel.text = text
        UIView.animate(withDuration: 2.5, delay: 0, options: .curveLinear, animations: {
            self.notificationLabel.alpha = 1
            self.notificationLabel.alpha = 0
        }, completion: nil)
    }
    
    
    func giveSmoothyBorder(for targetView: UIView){
        
//        targetView.layer.cornerRadius = 30.0
        targetView.layer.borderColor = UIColor.lightGray.cgColor
        targetView.layer.borderWidth = 1.5
        targetView.layer.shadowColor = UIColor.black.cgColor
        targetView.layer.shadowOpacity = 0.8
        targetView.layer.shadowRadius = 3.0
        targetView.layer.shadowOffset = CGSize(width: 2.0, height: 2.0)
        
    }
    
    func calculateFingerTips(videoRawData:AgoraVideoRawData, renderCanvas: AgoraRtcVideoCanvas){
        
        let pixelBuffer = CVPixelBuffer.createFrom(videoRawData)
        let deviceOrientation = UIDevice.current.orientation
        
        var cgImageOrientation: CGImagePropertyOrientation?
        switch deviceOrientation {
        case .portrait:
            self.memoryDeviceOrientation = .portrait
            cgImageOrientation = .leftMirrored
        case .portraitUpsideDown:
            self.memoryDeviceOrientation = .portraitUpsideDown
            cgImageOrientation = .rightMirrored
        case .landscapeRight:
            self.memoryDeviceOrientation = .landscapeRight
            cgImageOrientation = .upMirrored
        case .landscapeLeft:
            self.memoryDeviceOrientation = .landscapeLeft
            cgImageOrientation = .downMirrored
        default:
            if self.memoryDeviceOrientation == .portrait{
                cgImageOrientation = .leftMirrored
            }else if self.memoryDeviceOrientation == .portraitUpsideDown{
                cgImageOrientation = .rightMirrored
            }else if self.memoryDeviceOrientation == .landscapeRight{
                cgImageOrientation = .upMirrored
            }else if self.memoryDeviceOrientation == .landscapeLeft{
                cgImageOrientation = .downMirrored
            }else{
                cgImageOrientation = .none
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer!, orientation: cgImageOrientation!, options: [:])
        
        
        var fingerTips: [CGPoint] = []
        
        var leftHandLandMarks: [VNHumanHandPoseObservation.JointName:VNRecognizedPoint] = [:]
        defer {
            DispatchQueue.main.async { [self] in
                if let canvasView = renderCanvas.view, let sv = canvasView.superview{
                    if sv == self.localVideoView{
                        self.processPoints(fingerTips, leftHandLandMarks, self.localFingerPointsCanvasView!, Double(videoRawData.width), Double(videoRawData.height))
                    }else{
                        self.processPoints(fingerTips, leftHandLandMarks, self.remoteFingerPointsCanvasView!, Double(videoRawData.width), Double(videoRawData.height))
                    }
                }
                
            }
        }
        
        do{
            try handler.perform([self.handPoseRequest])
            guard let results = self.handPoseRequest.results?.prefix(2),
                  !results.isEmpty
            else {
                return
            }
            
            var recognizePoints:[VNRecognizedPoint] = []
            try results.enumerated().forEach{ index, observation in
                let fingers = try observation.recognizedPoints(.all)
                recognizePoints += fingers.values
                if index == 0{
                    // 只取第一个observation识别出来的手指点位，这个手不一定是左手
                    leftHandLandMarks = fingers
                }
            }
            
            
            fingerTips = recognizePoints.filter({$0.confidence > 0.8}).map({CGPoint(x: $0.location.x, y: 1-$0.location.y)})
            

        }catch{
            // Todo: - handle the capture error
            print("Error occurs when capture output")
            
        }
    }
}



