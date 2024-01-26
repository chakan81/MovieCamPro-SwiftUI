//
//  File.swift
//  
//
//  Created by ChakaN on 1/26/24.
//

import Foundation
import PhotosUI
import AVFoundation

struct LibraryItem: Identifiable, Hashable {
    let id: Int
    let thumbURL: URL
}

class LibraryManager: ObservableObject {
    static let shared = LibraryManager()
    
    @Published var library: [LibraryItem] = []
    @Published var editMode: Bool = false
    @Published var selectedItemIndex: IndexSet = []
    @Published var status: PHAuthorizationStatus
    @Published var player = AVPlayer(url: URL(fileURLWithPath: ""))
    
    var fileID: Int = 0
    
    var documentDirectoryURL: URL = FileManager.default.temporaryDirectory
    var videoDirectoryURL: URL = FileManager.default.temporaryDirectory
    var thumbDirectoryURL: URL = FileManager.default.temporaryDirectory
    
    init() {
        self.status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    }
}


extension LibraryManager {
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


extension LibraryManager {
    
    func getVideoURL(item: LibraryItem) -> URL {
        let fileName = item.thumbURL.lastPathComponent.dropLast(4)
        let fileNameWithExtention = fileName.appending(".mov")
        let url = self.videoDirectoryURL.appendingPathComponent(fileNameWithExtention, conformingTo: .url)
        
        return url
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
    
    // 다음 번호로 mov 파일 이름 만듦
    private func nextFileName() -> String? {
        var nextFileName: String? = nil
        
        let number = Int.random(in: 0...9999)
        
        nextFileName = String(format: "testAppMovieCamPro_%04d.mov", number)
        self.fileID = number
        
        return nextFileName
    }
    
    func nextFileURL() -> URL? {
        let destination: URL = FileManager.default.temporaryDirectory
        
        guard let nextFileName: String = nextFileName() else {
            print("No next Name")
            return nil
        }

        if #available(iOS 16.0, *) {
            let url = destination.appending(component: nextFileName, directoryHint: .inferFromPath)
            return url
        } else {
            let url = destination.appendingPathComponent(nextFileName, conformingTo: .url)
            return url
        }
    }
}


extension LibraryManager {
    func requestAuthorization() {
        switch self.status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                switch status {
                case .notDetermined:
                    print("결정장애!!!")
                case .denied, .restricted:
                    print("거부")
                case .authorized:
                    print("허용")
                case .limited:
                    print("일부 허용")
                @unknown default:
                    fatalError()
                }
                
                DispatchQueue.main.async {
                    self.status = status
                }
            }
        case .restricted:
            print("Photo Library Authorization : restricted")
        case .denied:
            print("Photo Library Authorization : denied")
        case .authorized:
            print("Photo Library Authorization : authorized")
        case .limited:
            print("Photo Library Authorization : limited")
        @unknown default:
            print("Photo Library Authorization : Error")
        }
    }
    
    func nextItem(item: LibraryItem) -> LibraryItem? {
        if self.library.count == 1 {
            return nil
        }
        
        guard let currentIndex = self.library.firstIndex(where: { currentItem in
            currentItem.id == item.id
        }) else {
            return self.library[0]
        }
        
        if currentIndex == 0 {
            let nextItem: LibraryItem = self.library[currentIndex + 1]
            return nextItem
        } else {
            let nextItem: LibraryItem = self.library[currentIndex - 1]
            return nextItem
        }
    }
}
