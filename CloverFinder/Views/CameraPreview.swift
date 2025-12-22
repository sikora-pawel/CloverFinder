//
//  CameraPreview.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 19/12/2025.
//
import SwiftUI
@preconcurrency import AVFoundation
import CoreGraphics

struct CameraPreview: UIViewRepresentable {
    
    let session: AVCaptureSession
    let boundingBoxes: [CGRect]

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        
        if let connection = view.previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.previewLayer.session = session
        uiView.updateBoundingBoxes(boundingBoxes)
    }
}

class CameraPreviewView: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()
    private let overlayLayer = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(previewLayer)
        
        // Konfiguracja warstwy overlay dla prostokątów
        overlayLayer.fillColor = UIColor.clear.cgColor
        overlayLayer.strokeColor = UIColor.red.cgColor
        overlayLayer.lineWidth = 2.0
        layer.addSublayer(overlayLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
        overlayLayer.frame = bounds
        
        if overlayLayer.frame != bounds {
            updateBoundingBoxes(boundingBoxes)
        }
    }
    
    private var boundingBoxes: [CGRect] = []
    
    func updateBoundingBoxes(_ boxes: [CGRect]) {
        boundingBoxes = boxes
        
        guard !boxes.isEmpty else {
            overlayLayer.path = nil
            return
        }
        
        let path = CGMutablePath()
        
        for box in boxes {
            
            let visionRectTopLeft = CGRect(
                x: box.origin.x,
                y: 1.0 - box.origin.y - box.height,
                width: box.width,
                height: box.height
            )
            
            let imageRect = CGRect(
                x: visionRectTopLeft.origin.y,
                y: 1.0 - visionRectTopLeft.origin.x - visionRectTopLeft.width,
                width: visionRectTopLeft.height,
                height: visionRectTopLeft.width
            )
            
            let layerRect = previewLayer.layerRectConverted(fromMetadataOutputRect: imageRect)
            
            path.addRect(layerRect)
        }
        
        overlayLayer.path = path
    }
}
