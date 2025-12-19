//
//  CameraPreview.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 19/12/2025.
//
import SwiftUI
@preconcurrency import AVFoundation

struct CameraPreview: UIViewRepresentable {
    
    let session: AVCaptureSession
    private let previewLayer = AVCaptureVideoPreviewLayer()

    func makeUIView(context: Context) -> some UIView {
        
        let uiView = UIView()
        
        DispatchQueue.main.async {
            self.previewLayer.session = session
        }
        previewLayer.videoGravity = .resizeAspectFill
        
        previewLayer.connection?.videoRotationAngle = 0
        
        uiView.layer.addSublayer(previewLayer)
        
        return uiView
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        DispatchQueue.main.async {
            self.previewLayer.session = session
        }
        previewLayer.frame = uiView.bounds
    }
}
