//
//  File.swift
//  
//
//  Created by ChakaN on 1/26/24.
//

import Foundation
import PhotosUI
import AVFoundation

class MovieFileManager: ObservableObject {
    
    static let shared = MovieFileManager()
    
    func removeFile(fileUrl: URL?) throws -> Void {
        guard let url = fileUrl else { return }
        
        try FileManager.default.removeItem(at: url)
        
        print("Removing \(url) has completed.")
        return
    }

    func copyFile(sourceFileURL: URL?, destinationURL: URL) throws -> Void {
        do {
            guard let fileURL = sourceFileURL else { return }
            try FileManager.default.copyItem(at: fileURL, to: destinationURL)
        } catch let error {
            print(error.localizedDescription)
        }

        try self.removeFile(fileUrl: sourceFileURL)
        return
    }

    func saveVideoFile(toPhotoLibrary fileURL: URL?) async throws -> Void {
        guard let url = fileURL else { return }
        
        try await PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false
            let creationRequest = PHAssetCreationRequest.forAsset()
            creationRequest.addResource(with: .video, fileURL: url, options: options)
        }
    }
}


extension MovieFileManager {
    
    func randomVideoFileURL() -> URL? {
        let tempDirectoryURL: URL = FileManager.default.temporaryDirectory
        
        let randomFileName: String = "temp_" + UUID().uuidString + ".mov"

        if #available(iOS 16.0, *) {
            let url = tempDirectoryURL.appending(component: randomFileName, directoryHint: .inferFromPath)
            return url
        } else {
            let url = tempDirectoryURL.appendingPathComponent(randomFileName, conformingTo: .url)
            return url
        }
    }
    
    func convertMovToMP4(url: URL?) async -> URL? {
        guard let inputURL: URL = url else { return nil }
        var outputURL: URL?
        
        if #available(iOS 16.0, *) {
            outputURL = URL(filePath: "\(inputURL.path().dropLast(4)).mp4")
        } else {
            outputURL = URL(fileURLWithPath: "\(inputURL.path.dropLast(4)).mp4")
        }
        
        print("converting URL: \(outputURL!.description)")

        let asset = AVAsset(url: inputURL)
        let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)
        exportSession?.outputURL = outputURL
        exportSession?.outputFileType = .mp4
        
        await exportSession?.export()
        print("complete converting!!")
        return outputURL
    }
}
