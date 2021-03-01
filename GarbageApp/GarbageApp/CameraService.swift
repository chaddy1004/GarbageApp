//
//  CameraService.swift
//  GarbageApp
//
//  Created by Chad  Paik on 2021-02-09.
//  Boiler plate code writte with https://medium.com/better-programming/effortless-swiftui-camera-d7a74abde37e as a reference. Thank you Ronaldo Rodriguez!
//

import Foundation
import Combine
import AVFoundation
import Photos
import UIKit


public class CameraService{
    typealias  PhotoCaptureSessionID = String
    
    // Ones marked with @Publihsed are functions that UI will talk to
    /*
     An AVCaptureDevice object represents a physical capture device and the properties associated with that device. You use a capture device to configure the properties of the underlying hardware. A capture device also provides input data (such as audio or video) to an AVCaptureSession object.
     */
    @Published public var flashMode: AVCaptureDevice.FlashMode = AVCaptureDevice.FlashMode.off
    
    @Published public var shouldShowAlertView = false
    
    @Published public var shouldShowSpinner = false
    
    @Published public var willCapturePhoto = false
    
    @Published public var isCameraButtonDisabled = true
    
    @Published public var isCameraAvailable = false
    
    @Published public var photo : Photo?
    
    
    // var is a variable, which can cange
    public var alertError: AlertError = AlertError()
    
    // let is a constant, which cannot change
    public let session = AVCaptureSession()
    
    private var isSessionRunning = false
    
    private var isConfigured = false
    
    private var setupResult: SessionSetupResult = SessionSetupResult.success
    
    // DispatchQueue: Object that manages the execution of tasks serially or concurrently on application's main thread or on a background thread
    // Work submitted to dispatch queues executes on a poll of threads managed by the system
    private let sessionQueue = DispatchQueue(label: "camera session queue")
    
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
    
    private let photoOutput = AVCapturePhotoOutput()
    
    private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    
    public func checkForPermissions(){
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video){
        case AVAuthorizationStatus.authorized:
            break
        case AVAuthorizationStatus.notDetermined:
            // For the first time the user gets the option to grant video accesss (notDetermined)
            // It suspends the session queue to delay session setup
            // Resume sessionQueue after the request is completed
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: AVMediaType.video) { granted in
                if !granted{
                    self.setupResult = SessionSetupResult.notAuthorized
                }
                else{
                    self.setupResult = SessionSetupResult.success
                }
                
                self.sessionQueue.resume()
            }
            
        default:
            // The user has previously denied access
            setupResult =  SessionSetupResult.notAuthorized
            
            DispatchQueue.main.async{
                self.alertError = AlertError(title: "Camera Access", message: "SwiftCamera doesn't have access to use your camera, please update your privacy settings.", primaryButtonTitle: "Settings", secondaryButtonTitle: nil, primaryAction: {
                                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                  options: [:], completionHandler: nil)
                                }, secondaryAction: nil)
                // Shows the alert message
                self.shouldShowAlertView = true
                self.isCameraAvailable = false
                self.isCameraButtonDisabled = true
            }
            
        }
    }
    
    private func configureSession(){
        // if sessionsetupresult is not successful, do not configure the session
        if self.setupResult != SessionSetupResult.success{
            return
        }
        
        self.session.beginConfiguration()
        self.session.sessionPreset = AVCaptureSession.Preset.photo
        
        // Try adding video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            // .default -> Returns the default device used to capture data of a given media type.
            if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                // If a rear dual camera is not available, default to the rear wide angle camera.
                defaultVideoDevice = backCameraDevice
            } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                // If the rear wide angle camera isn't available, default to the front wide angle camera.
                defaultVideoDevice = frontCameraDevice
            }
            
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                self.setupResult = SessionSetupResult.configurationFailed
                self.session.commitConfiguration()
                // Guard let must exit the current scope, unlike if let, which doesnt HAVE to call return
                return
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if self.session.canAddInput(videoDeviceInput) {
                self.session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
            } else {
                print("Couldn't add video device input to the session.")
                self.setupResult = SessionSetupResult.configurationFailed
                self.session.commitConfiguration()
                return
            }
        }
        catch {
            print("Couldn't create video device input: \(error)")
            self.setupResult = .configurationFailed
            self.session.commitConfiguration()
            return
        }
        
        // Add the photo output.
        if self.session.canAddOutput(photoOutput) {
            self.session.addOutput(photoOutput)
            
            self.photoOutput.isHighResolutionCaptureEnabled = true
            //
            self.photoOutput.maxPhotoQualityPrioritization = AVCapturePhotoOutput.QualityPrioritization.balanced
            
        } else {
            print("Could not add photo output to the session")
            self.setupResult = .configurationFailed
            self.session.commitConfiguration()
            return
        }
        
        self.session.commitConfiguration()
        self.isConfigured = true
        self.start()
    }
    
    public func configure() {
        /*
         Setup the capture session.
         In general, it's not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Don't perform these tasks on the main queue because
         AVCaptureSession.startRunning() is a blocking call, which can
         take a long time. Dispatch session setup to the sessionQueue, so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    public func start(){
        
        sessionQueue.async {
            if self.isSessionRunning == false && self.isConfigured{
                switch self.setupResult{
                case SessionSetupResult.success:
                    // the bottom line is calling AVCaptureSession.startRunning()
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                    
                    if self.session.isRunning{
                        DispatchQueue.main.async {
                            self.isCameraButtonDisabled = false
                            self.isCameraAvailable = true
                        }
                    }
                case SessionSetupResult.notAuthorized, SessionSetupResult.configurationFailed:
                    print("Application not autorized to use camera")
                    DispatchQueue.main.async {
                        self.alertError = AlertError(title: "Camera Error", message: "Camera configuration failed. Either your device camera is not available or its missing permissions", primaryButtonTitle: "Accept", secondaryButtonTitle: nil, primaryAction: nil, secondaryAction: nil)
                        self.shouldShowAlertView = true
                        self.isCameraButtonDisabled = true
                        self.isCameraAvailable = false
                    }
                }
            }
        }
    }
    
    public func stop(completion: (() -> ())? = nil) {
        sessionQueue.async {
            if self.isSessionRunning {
                if self.setupResult == .success {
                    self.session.stopRunning()
                    self.isSessionRunning = self.session.isRunning
                    
                    if !self.session.isRunning {
                        DispatchQueue.main.async {
                            self.isCameraButtonDisabled = true
                            self.isCameraAvailable = false
                            completion?()
                        }
                    }
                }
            }
        }
    }
    
    public func changeCamera(){
        DispatchQueue.main.async {
            self.isCameraButtonDisabled = true
        }
        
        sessionQueue.async {
            let currentVideoDevice = self.videoDeviceInput.device
            let currentPosition = currentVideoDevice.position
            
            let preferredPosition: AVCaptureDevice.Position
            let preferredDeviceType: AVCaptureDevice.DeviceType
            
            switch currentPosition{
            
            case AVCaptureDevice.Position.unspecified, AVCaptureDevice.Position.front:
                preferredPosition = AVCaptureDevice.Position.back
                preferredDeviceType = AVCaptureDevice.DeviceType.builtInWideAngleCamera
            
            case AVCaptureDevice.Position.back:
                preferredPosition = AVCaptureDevice.Position.front
                preferredDeviceType = AVCaptureDevice.DeviceType.builtInWideAngleCamera
            
            @unknown default:
                print("Unknown capture position. Defaulting to back, dual-camera.")
                preferredPosition = .back
                preferredDeviceType = .builtInWideAngleCamera
            }
            
            let devices = self.videoDeviceDiscoverySession.devices
            var newVideoDevice: AVCaptureDevice? = nil
            
            // First, seek a device with both the preferred position and device type. Otherwise, seek a device with only the preferred position.
            // $0 means the first parameter passed into the closure
            if let device = devices.first(where: { $0.position == preferredPosition && $0.deviceType == preferredDeviceType }) {
                newVideoDevice = device
            } else if let device = devices.first(where: { $0.position == preferredPosition }) {
                newVideoDevice = device
            }
            
            //essentially repreating the code from self.configureSession()
            // First try to see if newVideoDevice is not nil, and if it has valid device, set it to the variable videoDevice
            if let videoDevice = newVideoDevice {
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                    
                    self.session.beginConfiguration()
                    
                    // Remove the existing device input first, because AVCaptureSession doesn't support
                    // simultaneous use of the rear and front cameras.
                    self.session.removeInput(self.videoDeviceInput)
                    
                    if self.session.canAddInput(videoDeviceInput) {
                        self.session.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    } else {
                        self.session.addInput(self.videoDeviceInput)
                    }
                    
                    if let connection = self.photoOutput.connection(with: .video) {
                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .auto
                        }
                    }
                    
                    self.photoOutput.maxPhotoQualityPrioritization = .quality
                    
                    self.session.commitConfiguration()
                } catch {
                    print("Error occurred while creating video device input: \(error)")
                }
            }
            DispatchQueue.main.async {
                self.isCameraButtonDisabled = true
            }
            
        }
    }
    
    public func set(zoom: CGFloat){
        // just need to set the zoom factor on the device
        let factor = min(1,zoom)
        let device = self.videoDeviceInput.device
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = factor
            device.unlockForConfiguration()
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    public func capturePhoto(){
        // TODO
        print("capturePhoto() called")
    }
    
    
    
    
    
    


}
