//
//  FrameAnalyzer.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 22/12/2025.
//

import Foundation
import CoreMedia
import Vision
import ImageIO

final class FrameAnalyzer {
    
    weak var output: FrameAnalyzerOutput?
    
    func analyze(_ sampleBuffer: CMSampleBuffer) async {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("FrameAnalyzer: no CVPixelBuffer in sampleBuffer")
            return
        }

        // Capture the exact orientation used by Vision
        let visionOrientation: CGImagePropertyOrientation = .right
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: visionOrientation, options: [:])
        
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 20
        request.minimumConfidence = 0.6
        request.minimumSize = 0.05
        
        do {
            try handler.perform([request])
            
            let observations = request.results ?? []
            let boxes: [CGRect] = observations.map {
                $0.boundingBox
            }
            
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds

            let result = AnalysisResult(
                rectanglesDetected: boxes.count,
                boundingBoxes: boxes,
                timestamp: timestamp
            )

            output?.analyzerDidProduceResult(result, pixelBuffer: pixelBuffer, visionOrientation: visionOrientation)
            
        } catch {
            print("FrameAnalyzer: Vision error:", error)
        }
    }
}
