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
            // Vision zwraca współrzędne znormalizowane (0-1) w układzie, gdzie (0,0) jest w lewym dolnym rogu
            // Vision używa orientacji .right, więc współrzędne są w układzie obróconym o 90° w prawo
            // Musimy przekonwertować je na współrzędne warstwy preview
            
            // Vision boundingBox: (0,0) w lewym dolnym rogu, metadata output: (0,0) w lewym górnym rogu
            // Najpierw odwracamy Y, bo Vision ma (0,0) w lewym dolnym rogu
            let visionRectTopLeft = CGRect(
                x: box.origin.x,
                y: 1.0 - box.origin.y - box.height,
                width: box.width,
                height: box.height
            )
            
            // Teraz musimy uwzględnić orientację .right
            // Gdy Vision używa .right, współrzędne są obrócone o 90° w prawo
            // W układzie .right: X Vision -> Y obrazu, Y Vision -> X obrazu (odwrócone)
            // Przekształcenie dla orientacji .right (X bez odwracania, Y odwrócone):
            // x_image = y_vision
            // y_image = 1 - x_vision - width_vision
            // width_image = height_vision
            // height_image = width_vision
            let imageRect = CGRect(
                x: visionRectTopLeft.origin.y,
                y: 1.0 - visionRectTopLeft.origin.x - visionRectTopLeft.width,
                width: visionRectTopLeft.height,
                height: visionRectTopLeft.width
            )
            
            // Konwertujemy znormalizowane współrzędne na współrzędne warstwy preview
            // layerRectConverted automatycznie uwzględnia orientację połączenia (.landscapeRight) i aspect fill
            let layerRect = previewLayer.layerRectConverted(fromMetadataOutputRect: imageRect)
            
            path.addRect(layerRect)
        }
        
        overlayLayer.path = path
    }
}
