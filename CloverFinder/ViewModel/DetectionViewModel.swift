//
//  DetectionViewModel.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 22/12/2025.
//

import Foundation
import Combine

@MainActor
final class DetectionViewModel: ObservableObject {
    @Published var lastResultText: String = "No data yet"
    @Published var lastResult: AnalysisResult?
}

extension DetectionViewModel: FrameAnalyzerOutput {
    func analyzerDidProduceResult(_ result: AnalysisResult) {
        lastResult = result
        lastResultText = "Rectangles: \(result.rectanglesDetected)"
    }
}
