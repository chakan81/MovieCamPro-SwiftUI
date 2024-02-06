//
//  File.swift
//  
//
//  Created by ChakaN on 1/26/24.
//

import Foundation
import AVFoundation

public enum AVCaptureDeviceError: Error {
    case invalidMdeiaType(currentMediaType: AVMediaType)
    case VideoHDRNotSupported
    case unavailableFormat
    case invalidVideoDimensions
    case BackCameraNotSupported
}

public enum CameraServiceError: Error {
    case cannotAddDeviceInput
    case cannotAddDeviceOutput
    case captureSessionIsRunning
    case cannotSaveFile
    case zoomFactorOutOfRange
}
