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
    @Published public var flashMode: AVCaptureDevice.FlashMode = AVCaptureDevice.FlashMode.off
    
    @Published public var shouldShowAlertView = false
    
    @Published public var shouldShowSpinner = false
    
    @Published public var willCapturePhoto = false
    
    @Published public var isCameraButtonDisabled = true
    
    @Published public var isCameraUnavailable = true
    
    @Published public var photo : Photo?
    
    
    // var is a variable, which can cange
    public var alertError: AlertError = AlertError()
    
    // let is a constant, which cannot change
    public let session = AVCaptureSession()
    
    private var isSessionRunning = false
    
    private var isConfigured = false
    
    private var setupResult: SessionSetupResult = SessionSetupResult.success
    
    private let sessionQueue = DispatchQueue(label: "camera session queue")
    
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    private let photoOutput = AVCapturePhotoOutput()
    
    private var inProgressPhotoCaptureDelegates = [Int64: PhotoCaptureProcessor]()
    
    public func checkPermissions(){
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video){
        case AVAuthorizationStatus.authorized:
            break
        case AVAuthorizationStatus.notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: AVMediaType.video) { granted in
                if !granted{
                    self.setupResult = SessionSetupResult.notAuthorized
                }
                
                self.sessionQueue.resume()
            }
            
        default:
            setupResult =  SessionSetupResult.notAuthorized
            
            DispatchQueue.main.async{
                self.alertError = AlertError(title: "Camera Access", message: "SwiftCamera doesn't have access to use your camera, please update your privacy settings.", primaryButtonTitle: "Settings", secondaryButtonTitle: nil, primaryAction: {
                                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                  options: [:], completionHandler: nil)
                                }, secondaryAction: nil)
                self.shouldShowAlertView = true
                self.isCameraUnavailable = true
                self.isCameraButtonDisabled = true
            }
            
        }
    }
}


