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
        
        // Ustawiamy orientację połączenia, aby odpowiadała orientacji Vision (.right)
        if let connection = view.previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .landscapeRight
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
        // Odśwież prostokąty po zmianie rozmiaru (konwersja współrzędnych zależy od rozmiaru warstwy)
        updateBoundingBoxes(boundingBoxes)
    }
    
    private var boundingBoxes: [CGRect] = []
    
    func updateBoundingBoxes(_ boxes: [CGRect]) {
        boundingBoxes = boxes
        
        guard !boxes.isEmpty else {
            overlayLayer.path = nil
            return
        }
        
        // Tworzymy ścieżkę zawierającą wszystkie prostokąty
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
