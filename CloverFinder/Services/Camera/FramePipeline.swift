//
//  FramePipeline.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 22/12/2025.
//

import Foundation
import CoreMedia

protocol FramePipelineOutput: AnyObject {
    func pipelineDidSelectFrame(_ sampleBuffer: CMSampleBuffer)
}

final class FramePipeline {
    private var frameCounter: Int = 0
    private let analyzeEveryNthFrame: Int
    
    weak var output: FramePipelineOutput?

    init(analyzeEveryNthFrame: Int) {
        self.analyzeEveryNthFrame = max(1, analyzeEveryNthFrame)
    }

    func shouldAnalyze(_ sampleBuffer: CMSampleBuffer) -> Bool {
        frameCounter += 1
        return frameCounter % analyzeEveryNthFrame == 0
    }
    
    func ingest(_ sampleBuffer: CMSampleBuffer) {
        if shouldAnalyze(sampleBuffer) {
            output?.pipelineDidSelectFrame(sampleBuffer)
        }
    }
}
