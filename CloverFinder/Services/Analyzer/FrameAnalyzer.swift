//
//  FrameAnalyzer.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 22/12/2025.
//

import Foundation
import CoreMedia
import Vision

final class FrameAnalyzer {
    
    weak var output: FrameAnalyzerOutput?
    
    func analyze(_ sampleBuffer: CMSampleBuffer) async {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("FrameAnalyzer: no CVPixelBuffer in sampleBuffer")
            return
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        //print("FrameAnalyzer: pixelBuffer \(width)x\(height) at \(timestamp)")
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        
        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 10
        request.minimumConfidence = 0.6
        
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

            output?.analyzerDidProduceResult(result)
            
        } catch {
            print("FrameAnalyzer: Vision error:", error)
        }
    }
}
