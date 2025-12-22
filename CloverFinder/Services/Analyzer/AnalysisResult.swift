//
//  AnalysisResult.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 22/12/2025.
//

import Foundation

protocol FrameAnalyzerOutput: AnyObject {
    func analyzerDidProduceResult(_ result: AnalysisResult)
}

struct AnalysisResult: Sendable {
    let rectanglesDetected: Int
    let boundingBoxes: [CGRect]
    let timestamp: TimeInterval
}

