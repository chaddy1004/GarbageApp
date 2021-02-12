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
    
    private var isConfigured = false
    
    private var setupResult: SessionSetupResult = .success
    
    
    
    
    
    private let sessionQueue = DispatchQueue(label: "camera session queue")
}


