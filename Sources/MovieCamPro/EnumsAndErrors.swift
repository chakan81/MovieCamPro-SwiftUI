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
}

public enum CameraServiceError: Error {
    case cannotAddDeviceInput
    case cannotAddDeviceOutput
    case captureSessionIsRunning
}
