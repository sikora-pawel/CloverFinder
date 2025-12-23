//
//  AnalysisResult.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 22/12/2025.
//

import Foundation
import CoreGraphics
import CoreVideo
import ImageIO

protocol FrameAnalyzerOutput: AnyObject {
    func analyzerDidProduceResult(_ result: AnalysisResult, pixelBuffer: CVPixelBuffer, visionOrientation: CGImagePropertyOrientation)
}

struct AnalysisResult: Sendable {
    let rectanglesDetected: Int
    let boundingBoxes: [CGRect]
    let timestamp: TimeInterval
}

