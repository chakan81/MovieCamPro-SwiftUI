//
//  CameraService.swift
//
//
//  Created by ChakaN on 1/20/24.
//

import SwiftUI
import AVFoundation

public class CameraService: NSObject, ObservableObject {
    private let sessionQueue = DispatchQueue(label: "session Queue")
    public let captureSession = AVCaptureSession()

    private let libraryManager = MovieFileManager.shared
    
    private var videoDeviceInput: AVCaptureDeviceInput!
    private var audioDeviceInput: AVCaptureDeviceInput!
    private var videoDevice: AVCaptureDevice!
    private var audioDevice: AVCaptureDevice!
    
    private var discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera], mediaType: .video, position: .unspecified)
    private var scoredFormats: [AVCaptureDevice.ScoredFormat] = []
    
    private let movieFileOutput = AVCaptureMovieFileOutput()
    
    @Published public var activeFormatInfo: FormatInfo?
    @Published public var isRecording: Bool = false
    @Published public var dimensions: CMVideoDimensions = CMVideoDimensions(width: 3840, height: 2160)
    @Published public var frameRate: Double = 120.0
    @Published public var zoomFactor: CGFloat = 3.0
    var zoomWeightingFactors: [String: CGFloat] = ["Wide": 1]
    @Published public var dolbyOn: Bool = true
    
    @Published public var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published public var micStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    
    @Published public var error: Error?
    @Published public var errorMessage: String?
    
    
    public func setupSession() {
        sessionQueue.async {
            self.captureSession.sessionPreset = .high
            self.updateZoomWeightingFactors()
            self.setDiscoverySession()
            self.setInputDevice()
            self.addInput()
            self.scoreFormats()
            self.setActiveFormat(dimensions: self.dimensions, frameRate: self.frameRate)
            self.addOutput()
            self.setupRecording()
            DispatchQueue.main.async {
                self.updateAtciveFormatInfo()
            }
            
            self.printAllScoredFormats(useFormatInfo: true)
            self.setZoomFactor(zoomFactor: self.zoomFactor)
        }
    }
    
    func getZoomFactorSwitchOverArray() throws -> [NSNumber] {
        let localDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTripleCamera, .builtInDualCamera, .builtInWideAngleCamera], mediaType: .video, position: .back)
        
        let devices = localDiscoverySession.devices
        
        guard let device = devices.first(where: { device in
            device.position == .back
        }) else { throw AVCaptureDeviceError.BackCameraNotSupported }
        
        let switchOverArray = device.virtualDeviceSwitchOverVideoZoomFactors
        
        return switchOverArray
    }
    
    func updateZoomWeightingFactors() {
        var weightingFactorArray: [String: CGFloat] = ["": 0]
        do {
            let array = try self.getZoomFactorSwitchOverArray()
            let hasUltraWide = discoverySession.devices.contains(where: { device in
                device.deviceType == AVCaptureDevice.DeviceType.builtInUltraWideCamera
            })
            
            let hasTelephoto = discoverySession.devices.contains(where: { device in
                device.deviceType == AVCaptureDevice.DeviceType.builtInTelephotoCamera
            })
            
            print("First of Array: \(CGFloat(truncating: array.first!))")
            
            switch (hasUltraWide, hasTelephoto) {
            case (true, true):
                weightingFactorArray = ["UltraWide": CGFloat(truncating: array.first!), "Wide": 1, "Telephoto": CGFloat(truncating: array.first!) / CGFloat(truncating: array.last!)]
            case (true, false):
                weightingFactorArray = ["UltraWide": CGFloat(truncating: array.first!), "Wide": 1]
            case (false, true):
                weightingFactorArray = ["Wide": 1, "Telephoto": (1 / CGFloat(truncating: array.first!))]
            case (false, false):
                weightingFactorArray = ["Wide": 1]
            }
            
            print("switchOverArray: \(array.description)")
            print("weightingFactorArray: \(weightingFactorArray.description)")
        } catch {
            popError(error: error)
        }
        
        self.zoomWeightingFactors = weightingFactorArray
        
        return
    }
    
    func setZoomFactor(zoomFactor: CGFloat) {
        var weightedZoomFactor: CGFloat = 0
        
        switch self.videoDevice.deviceType {
        case .builtInUltraWideCamera:
            weightedZoomFactor = zoomFactor * (self.zoomWeightingFactors["UltraWide"] ?? 2.0)
        case .builtInWideAngleCamera:
            weightedZoomFactor = zoomFactor * (self.zoomWeightingFactors["Wide"] ?? 1.0)
        case .builtInTelephotoCamera:
            weightedZoomFactor = zoomFactor * (self.zoomWeightingFactors["Telephoto"] ?? 0.5)
        default:
            weightedZoomFactor = zoomFactor
        }
        
        do {
            if weightedZoomFactor < 1.0 {
                throw CameraServiceError.zoomFactorOutOfRange
            }
            try self.videoDevice.setZoomFactor(zoomFactor: weightedZoomFactor)
        } catch {
            popError(error: error)
        }
        
        print("Video Device: \(self.videoDevice.deviceType)\nweightedZoomFactor: \(weightedZoomFactor)")
        
    }
    
    func setDiscoverySession() {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
        var telephotoZoomFactor: CGFloat = 1.0
        
        if let telephotoWeightingFactor = self.zoomWeightingFactors["Telephoto"] {
            telephotoZoomFactor = 1 / telephotoWeightingFactor
        } else {
            telephotoZoomFactor = .infinity
        }
        
        if self.zoomFactor < 1.0 {
            deviceTypes = [.builtInUltraWideCamera, .builtInWideAngleCamera]
        } else if self.zoomFactor >= telephotoZoomFactor {
            deviceTypes = [.builtInTelephotoCamera, .builtInWideAngleCamera]
        } else {
            deviceTypes = [.builtInWideAngleCamera]
        }
        
        self.discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .unspecified)
        
        return
    }
    
    func setInputDevice() {
        
        captureSession.beginConfiguration()
        
        let videoDevice = discoverySession.devices.first
        self.videoDevice = videoDevice
        
        if #available(iOS 17.0, *) {
            guard let audioDevice = AVCaptureDevice.default(.microphone, for: .audio, position: .unspecified) else { return  }
            self.audioDevice = audioDevice
        } else {
            guard let audioDevice = AVCaptureDevice.default(.builtInMicrophone, for: .audio, position: .unspecified) else { return }
            self.audioDevice = audioDevice
        }
        
        captureSession.commitConfiguration()
        return
    }
    
    func addInput() {
        
        captureSession.beginConfiguration()
        
        if self.videoDeviceInput != nil {
            captureSession.removeInput(self.videoDeviceInput)
        }
        
        if self.audioDeviceInput != nil {
            captureSession.removeInput(self.audioDeviceInput)
        }
        
        do {
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: self.videoDevice)
            let audioDeviceInput = try AVCaptureDeviceInput(device: self.audioDevice)
            
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
            } else {
                throw CameraServiceError.cannotAddDeviceInput
            }
            
            if captureSession.canAddInput(audioDeviceInput) {
                captureSession.addInput(audioDeviceInput)
                self.audioDeviceInput = audioDeviceInput
            } else {
                throw CameraServiceError.cannotAddDeviceInput
            }
            
        } catch CameraServiceError.cannotAddDeviceInput {

            popError(error: CameraServiceError.cannotAddDeviceInput)
            return
            
        } catch let error {
            
            popError(error: error)
            return
            
        }
        
        captureSession.commitConfiguration()
        return
    }
    
    func addOutput() {
        captureSession.beginConfiguration()
        
        if captureSession.canAddOutput(movieFileOutput) {
            captureSession.addOutput(movieFileOutput)
        } else {
            print("AVCaptureSession can not add AVCaptureDeviceOutput.")
            return
        }
        
        DispatchQueue.main.async {
            self.isRecording = self.movieFileOutput.isRecording
        }
        
        captureSession.commitConfiguration()
        return
    }
    
    func setupRecording() {
        
    }
    
    public func startSession() {
        sessionQueue.async {
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            } else {
                print("CaptureSession is running. Can't start CaptureSession.")
            }
        }
        
        return
    }
    
    public func stopSession() {
        sessionQueue.async {
            if self.captureSession.isRunning {
                self.captureSession.startRunning()
            } else {
                print("CaptureSession is not running. Can't stop CaptureSession.")
            }
        }
        
        return
    }
    
    public func startRecording() {
        
        // make outputURL
        guard let outputFileURL = self.libraryManager.randomVideoFileURL() else { return }
        
        if !self.isRecording {
            AudioServicesPlaySystemSoundWithCompletion(1117) {
                self.movieFileOutput.startRecording(to: outputFileURL, recordingDelegate: self)
                print("Recording started.")
            }
        }
    }
    
    public func stopRecording() {
        if self.isRecording {
            self.movieFileOutput.stopRecording()
            print("Recording stopped.")
        }
    }
}

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    public func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]) {
        
    }
    
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        
        if let error = error {
            print(error.localizedDescription)
            return
        }
        
        Task {
            // save function
            do {
                try await self.libraryManager.saveVideoFile(toPhotoLibrary: outputFileURL)
            } catch {
                self.popError(error: CameraServiceError.cannotSaveFile)
            }
            AudioServicesPlaySystemSoundWithCompletion(1118, nil)
        }
    }
}

extension CameraService {
    func scoreFormats() {
        self.scoredFormats = videoDevice.scoreAndSortFormats(dolbyOn: self.dolbyOn)
    }
    
    func setActiveFormat(dimensions: CMVideoDimensions, frameRate: Double) {
        
        do {
            guard let properFormat = try self.videoDevice.findProperFormat(scoredFormats: self.scoredFormats, dimension: dimensions, frameRate: frameRate) else {
                try self.videoDevice.setActiveFormat(format: self.scoredFormats.first?.format)
                throw AVCaptureDeviceError.unavailableFormat
            }

            try self.videoDevice.setActiveFormat(format: properFormat)
        } catch let error {
            popError(error: error)
        }
        
        return
    }
    
    public func updateAtciveFormatInfo() {
        let activeFormatInfo = FormatInfo(format: self.videoDevice.activeFormat)
        
        self.activeFormatInfo = activeFormatInfo
        
        return
    }
    
    func printAllAvailabeFormats(useFormatInfo: Bool) {
        self.videoDevice.printFormatArray(formats: self.videoDevice.formats, useFormatInfo: useFormatInfo)
    }
    
    func printAllScoredFormats(useFormatInfo: Bool) {
        self.videoDevice.printFormatArray(formats: self.scoredFormats.map({ scoredFormat in
            return scoredFormat.format
        }), useFormatInfo: useFormatInfo)
    }
}
extension CameraService {
    public func updateDolbyState() {
        self.scoreFormats()
        self.setActiveFormat(dimensions: self.dimensions, frameRate: self.frameRate)
    }
    
    public func setFrameRate(frameRate: Double) {
        do {
            try self.videoDevice.setFrameRate(frameRate: frameRate)
        } catch let error {
            popError(error: error)
        }
    }
    
    public func setSmoothAutoFocus(enable: Bool) {
        do {
            try self.videoDevice.setSmoothAutoFocus(enable: enable)
        } catch let error {
            popError(error: error)
        }
    }
    
    public func setExposure(bias: Float) async {
        do {
            try await self.videoDevice.setExposure(EVunit: bias)
        } catch let error {
            popError(error: error)
        }
    }
    
    public func setHDR(isHDROn: Bool) {
        do {
            try self.videoDevice.setHDR(isHDROn: isHDROn)
        } catch let error {
            popError(error: error)
        }
    }
}

extension CameraService {
    func requestAuthorization(media: AVMediaType) {
        let status = AVCaptureDevice.authorizationStatus(for: media)
        
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: media) { authorized in
                DispatchQueue.main.async {
                    if authorized {
                        if media == .video {
                            self.cameraStatus = .authorized
                        } else if media == .audio {
                            self.micStatus = .authorized
                        }
                    } else {
                        if media == .video {
                            self.cameraStatus = .denied
                        } else if media == .audio {
                            self.micStatus = .denied
                        }
                    }
                }
            }
        case .restricted:
            DispatchQueue.main.async {
                if media == .video {
                    self.cameraStatus = .restricted
                } else if media == .audio {
                    self.micStatus = .restricted
                }
            }
        case .denied:
            DispatchQueue.main.async {
                if media == .video {
                    self.cameraStatus = .restricted
                } else if media == .audio {
                    self.micStatus = .restricted
                }
            }
        case .authorized:
            DispatchQueue.main.async {
                if media == .video {
                    self.cameraStatus = .authorized
                } else if media == .audio {
                    self.micStatus = .authorized
                }
            }
        @unknown default:
            fatalError()
        }
    }
}


// Error Handling
extension CameraService {
    public func popError(error: Error?) {
        DispatchQueue.main.async {
            guard let error = error else {
                self.errorMessage = nil
                return
            }
            
            self.errorMessage = self.interpretError(error: error)
            self.error = error
        }
        
        return
    }
    
    public func resetError() {
        DispatchQueue.main.async {
            self.error = nil
            self.errorMessage = nil
        }
        
        return
    }
    
    func interpretError(error: Error?) -> String? {
        var message: String = ""
        
        guard let error = error else {
            return nil
        }
        
        switch error {
        case AVCaptureDeviceError.VideoHDRNotSupported:
            message = "HDR video is not supported."
        case AVCaptureDeviceError.invalidMdeiaType(currentMediaType: let mediaType):
            message = "Invalide MediaType. Current MediaType is \(mediaType)."
        case AVCaptureDeviceError.unavailableFormat:
            message = "Foramat is not available"
        case AVCaptureDeviceError.invalidVideoDimensions:
            message = "Not a standard video dimension."
        case AVCaptureDeviceError.BackCameraNotSupported:
            message = "Back Camera is not supported."
        case CameraServiceError.cannotAddDeviceInput:
            message = "AVCaptureSession can not add AVCaptureDeviceInput."
        case CameraServiceError.cannotAddDeviceOutput:
            message = "AVCaptureSession can not add AVCaptureDeviceOutput."
        case CameraServiceError.captureSessionIsRunning:
            message = "CaptureSession is on running."
        case CameraServiceError.zoomFactorOutOfRange:
            message = "weightedZoomFactor can not be less than 1.0"
        default:
            message = error.localizedDescription
        }
        
        return message
    }
}
