//
//  FrameAnalyzer.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 22/12/2025.
//

import Foundation
import CoreMedia

final class FrameAnalyzer {
    func analyze(_ sampleBuffer: CMSampleBuffer) async {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        print("Analyzer received frame at timestamp:", timestamp)
    }
}
