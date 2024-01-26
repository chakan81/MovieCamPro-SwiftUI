//
//  CameraPreview.swift
//
//
//  Created by ChakaN on 1/20/24.
//

import SwiftUI
import AVFoundation

public struct CameraPreview: UIViewRepresentable {
    
    public class VideoPreviewView: UIView {
        public override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    let session: AVCaptureSession
    
    public init(session: AVCaptureSession) {
        self.session = session
    }
    
    public func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        
        view.videoPreviewLayer.session = session
        
        return view
    }
    
    public func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        
    }
}
