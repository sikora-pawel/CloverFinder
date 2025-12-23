//
//  DetectionViewModel.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 22/12/2025.
//

import Foundation
import Combine
import CoreGraphics

@MainActor
final class DetectionViewModel: ObservableObject {
    @Published var lastResultText: String = "No data yet"
    @Published var lastResult: AnalysisResult?
    
    /// Temporal tracker for smoothing and filtering bounding boxes
    private let boxTracker = TemporalBoxTracker()
    
    init() {
        // Configure tracker with reasonable defaults for ~30 FPS
        boxTracker.iouThreshold = 0.3
        boxTracker.smoothingAlpha = 0.3
        boxTracker.minFramesToConfirm = 2  // Filter out single-frame noise
        boxTracker.maxMissedFrames = 5     // ~167ms at 30 FPS
        boxTracker.maxJumpDistance = 0.3  // Reset on large jumps
    }
}

extension DetectionViewModel: FrameAnalyzerOutput {
    func analyzerDidProduceResult(_ result: AnalysisResult) {
        // Apply temporal smoothing and noise filtering
        let smoothedBoxes = boxTracker.update(with: result.boundingBoxes)
        
        // Create updated result with smoothed boxes
        let smoothedResult = AnalysisResult(
            rectanglesDetected: smoothedBoxes.count,
            boundingBoxes: smoothedBoxes,
            timestamp: result.timestamp
        )
        
        lastResult = smoothedResult
        lastResultText = "Rectangles: \(smoothedResult.rectanglesDetected) (raw: \(result.rectanglesDetected))"
    }
}
