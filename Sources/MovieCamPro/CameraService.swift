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

    private let libraryManager = LibraryManager.shared
    
    private var videoDeviceInput: AVCaptureDeviceInput!
    private var audioDeviceInput: AVCaptureDeviceInput!
    private var videoDevice: AVCaptureDevice!
    private var audioDevice: AVCaptureDevice!
    
    private var discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInTripleCamera], mediaType: .video, position: .unspecified)
    private var scoredFormats: [AVCaptureDevice.ScoredFormat] = []
    
    private let movieFileOutput = AVCaptureMovieFileOutput()
    
    @Published public var activeFormatInfo: FormatInfo?
    @Published public var isRecording: Bool = false
    @Published public var dimensions: CMVideoDimensions = CMVideoDimensions(width: 3840, height: 1920)
    @Published public var frameRate: Double = 30.0
    @Published public var dolbyOn: Bool = false
    
    @Published public var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published public var micStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    
    @Published public var error: Error?
    @Published public var errorMessage: String?
    
    
    public func setupSession() {
        sessionQueue.async {
            self.captureSession.sessionPreset = .high
            self.setInputDevice()
            self.addInput()
            self.scoreFormats()
            self.setActiveFormat(dimensions: self.dimensions, frameRate: self.frameRate, dolbyOn: self.dolbyOn)
            self.addOutput()
//            self.setupRecording()
//            self.printAllAvailabeFormats()
            DispatchQueue.main.async {
                self.updateAtciveFormatInfo()
            }
            
            self.videoDevice.printFormatArray(formats: self.scoredFormats.map({ scoredFormat in
                return scoredFormat.format
            }))
        }
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
        guard let outputFileURL = self.libraryManager.nextFileURL() else { return }
        
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
                print("Saving movie has something worng.")
            }
            AudioServicesPlaySystemSoundWithCompletion(1118, nil)
        }
    }
}

extension CameraService {
    func scoreFormats() {
        self.scoredFormats = videoDevice.scoreAndSortFormats()
    }
    
    func setActiveFormat(dimensions: CMVideoDimensions, frameRate: Double, dolbyOn: Bool) {
        
//        for i in 0...self.scoredFormats.count - 1 {
//            if scoredFormats[i].score =
//        }
        
        do {
            try self.videoDevice.setActiveFormat(format: self.scoredFormats.first!.format)
        } catch let error {
            popError(error: error)
        }
        
        return
    }
    
    func updateAtciveFormatInfo() {
        let activeFormatInfo = FormatInfo(format: self.videoDevice.activeFormat)
        
        self.activeFormatInfo = activeFormatInfo
        
        return
    }
    
    func printAllAvailabeFormats() -> Void {
        self.videoDevice.printAllAvailableFormats()
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
        case CameraServiceError.cannotAddDeviceInput:
            message = "AVCaptureSession can not add AVCaptureDeviceInput."
        case CameraServiceError.cannotAddDeviceOutput:
            message = "AVCaptureSession can not add AVCaptureDeviceOutput."
        case CameraServiceError.captureSessionIsRunning:
            message = "CaptureSession is on running."
        default:
            message = error.localizedDescription
        }
        
        return message
    }
}
