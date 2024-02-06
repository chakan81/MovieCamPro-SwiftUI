//
//  AVCaptureDevice.swift
//
//
//  Created by ChakaN on 1/20/24.
//

import Foundation
import AVFoundation

public struct FormatInfo {
    var dimension: CMVideoDimensions
    var frameRateRange: AVFrameRateRange?
    var focusSystem: AVCaptureDevice.Format.AutoFocusSystem
    var mediaSubType: CMFormatDescription.MediaSubType
    
    public init(format: AVCaptureDevice.Format) {
        self.dimension = format.formatDescription.dimensions
        self.frameRateRange = format.videoSupportedFrameRateRanges.first
        self.focusSystem = format.autoFocusSystem
        self.mediaSubType = format.formatDescription.mediaSubType
    }
    
    public func convertFormatInfoToString() -> String {
        let infoString = "=====================\n width: \(dimension.width), height: \(dimension.height)\n frame rate range: \(frameRateRange?.minFrameRate ?? 0) ~ \(frameRateRange?.maxFrameRate ?? 0)\n focus system: \(focusSystem.rawValue)\n Media SubType: \(mediaSubType)\n====================="
        
        return infoString
    }
}

extension AVCaptureDevice {

    struct ScoredFormat {
        let format: AVCaptureDevice.Format
        let score: Int
        let dimensionScore: Int
        let frameRateScore: Int
        let isVideoHDRSupported: Bool
        let isDolbySupported: Bool
        
        init(format: AVCaptureDevice.Format, score: Int, dimensionScore: Int, frameRateScore: Int, isVideoHDRSupported: Bool, isDolbySupported: Bool) {
            self.format = format
            self.score = score
            self.dimensionScore = dimensionScore
            self.frameRateScore = frameRateScore
            self.isVideoHDRSupported = isVideoHDRSupported
            self.isDolbySupported = isDolbySupported
        }
    }
    
    func setActiveFormat(format: Format?) throws -> Void {
        guard let format = format else {
            throw AVCaptureDeviceError.unavailableFormat
        }
        
        try lockForConfiguration()
        activeFormat = format
        unlockForConfiguration()
        
        return
    }
    
    func findProperFormat(scoredFormats: [ScoredFormat], dimension: CMVideoDimensions, frameRate: Double) throws -> AVCaptureDevice.Format? {
        let dimensionScore = self.getDimensionScore(dimension: dimension)
        
        if dimensionScore == 0 {
            throw AVCaptureDeviceError.invalidVideoDimensions
        }
        
        guard let scoredFormat = try scoredFormats.first(where: { scoredFormat in
            try scoredFormat.dimensionScore <= dimensionScore && self.checkFrameRate(format: scoredFormat.format, frameRate: frameRate)
        }) else {
            return nil
        }
        
        return scoredFormat.format
    }
    
    func scoreAndSortFormats(dolbyOn: Bool) -> [ScoredFormat] {
        var scoredFormats: [ScoredFormat] = []
        
        for i in 0...formats.count - 1 {
            let scoredFormat = scoreFormat(format: formats[i], dolbyOn: dolbyOn)
            
            scoredFormats.append(scoredFormat)
        }
        
        scoredFormats.sort { $0.score > $1.score }
        
        return scoredFormats
    }
    
    func printFormatArray(formats: [Format], useFormatInfo: Bool) {
        for i in 0...formats.count - 1 {
            let formatInfo: FormatInfo = FormatInfo(format: formats[i])
            if useFormatInfo {
                print("Formats[\(i)]\n\(formatInfo.convertFormatInfoToString())")
            } else {
                print("Formats[\(i)], \(formats[i].description)")
            }
        }
    }
    
    func scoreFormat(format: Format, dolbyOn: Bool) -> ScoredFormat {
        var totalScore: Int = 0
        var isVideoHDRSupported: Bool = false
        var isDolbySupported: Bool = false
        
        let dimensionScore: Int = getDimensionScore(dimension: format.formatDescription.dimensions)
        let binnedScore: Int = getBinnedScore(format: format)
        let frameRateScore: Int = getFrameRateScore(format: format)
        let mediaSubTypeScore: Int = getMediaSubTypeScore(format: format, dolbyOn: dolbyOn)
        let focusSystemScore: Int = getFocusSystemScore(format: format)
        
        totalScore = dimensionScore * 10000 + binnedScore * 1000 + frameRateScore * 100 + mediaSubTypeScore * 10 + focusSystemScore
        
        if mediaSubTypeScore == 4 {
            isDolbySupported = true
        } else {
            isDolbySupported = false
        }
        
        if format.isVideoHDRSupported {
            isVideoHDRSupported = true
        } else {
            isVideoHDRSupported = false
        }
        
        let scoredFormat = ScoredFormat(format: format, score: totalScore, dimensionScore: dimensionScore, frameRateScore: binnedScore, isVideoHDRSupported: isVideoHDRSupported, isDolbySupported: isDolbySupported)
        
        return scoredFormat
    }
}

extension AVCaptureDevice {
    func checkFrameRate(format: Format, frameRate: Double) throws -> Bool {
        if !hasMediaType(.video) {
            throw AVCaptureDeviceError.invalidMdeiaType(currentMediaType: format.mediaType)
        }
        
        guard let range = format.videoSupportedFrameRateRanges.first,
              range.minFrameRate...range.maxFrameRate ~= frameRate else {
            return false
        }
        
        return true
    }
}

extension AVCaptureDevice {
    func getDimensionScore(dimension: CMVideoDimensions) -> Int {
        let unitScore = 10
        var score: Int = 0
        
        switch (dimension.width, dimension.height) {
        case (3840, 2160):
            score = unitScore * 4
        case (1920, 1080):
            score = unitScore * 3
        case (1280, 720):
            score = unitScore * 2
        case (640, 480):
            score = unitScore
        default:
            score = 0
        }
        
        return score
    }
    
    func getFrameRateScore(format: Format) -> Int {
        let unitScore = 2
        var score = 0
        guard let range = format.videoSupportedFrameRateRanges.first else {
            return 0
        }
        
        switch range.maxFrameRate {
        case 60:
            score = unitScore * 4
        case 30:
            score = unitScore * 3
        case 120:
            score = unitScore * 2
        case 240:
            score = unitScore
        default:
            score = 0
        }
        
//        let score = Int(range.maxFrameRate)
        
        return score
    }

    func getFocusSystemScore(format: Format) -> Int {
        let unitScore = 2
        var score = 0
        
        switch format.autoFocusSystem {
        case .phaseDetection:
            score = unitScore * 2
        case .contrastDetection:
            score = unitScore
        default:
            score = 0
        }
        
        return score
    }
    
    func getMediaSubTypeScore(format: Format, dolbyOn: Bool) -> Int {
        let unitScore = 2
        let dolbyFactor = dolbyOn ? 2 : 0
        var score = 0
        
        switch format.formatDescription.mediaSubType {
        case CMFormatDescription.MediaSubType(string: "x420"):
            score = unitScore * dolbyFactor
        case CMFormatDescription.MediaSubType(string: "420f"):
            score = unitScore
        default:
            score = 0
        }
        
        return score
    }
    
    func getBinnedScore(format: Format) -> Int {
        if format.isVideoBinned {
            return 0
        } else {
            return 5
        }
    }
}

extension AVCaptureDevice {
    func setFrameRate(frameRate: Double) throws {
        if try checkFrameRate(format: activeFormat, frameRate: frameRate) {
            try lockForConfiguration()
            
            let frameDuration = CMTimeMake(value: 1, timescale: Int32(frameRate))
            
            activeVideoMinFrameDuration = frameDuration
            activeVideoMaxFrameDuration = frameDuration
            
            unlockForConfiguration()
        }
        
        return
    }
    
//    @available(iOS 14.0, *)
    func setSmoothAutoFocus(enable mode: Bool) throws {
        if isSmoothAutoFocusSupported {
            try lockForConfiguration()
            isSmoothAutoFocusEnabled = mode
            unlockForConfiguration()
        }
        
        return
    }
    
    func setExposure(EVunit bias: Float) async throws {
        try lockForConfiguration()
        await setExposureTargetBias(bias)
        unlockForConfiguration()
        
        return
    }
    
    func setHDR(isHDROn: Bool) throws {
        if activeFormat.isVideoHDRSupported {
            try lockForConfiguration()
            automaticallyAdjustsVideoHDREnabled = false
            isVideoHDREnabled = isHDROn
            unlockForConfiguration()
        } else {
            throw AVCaptureDeviceError.VideoHDRNotSupported
        }
        
        return
    }
    
    func setZoomFactor(zoomFactor: CGFloat) throws {
        try lockForConfiguration()
        self.videoZoomFactor = zoomFactor
        unlockForConfiguration()
    }
}
