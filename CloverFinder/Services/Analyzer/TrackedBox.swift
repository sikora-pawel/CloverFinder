//
//  TrackedBox.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 22/12/2025.
//

import Foundation
import CoreGraphics

/// Track state for lifecycle management
enum TrackState {
    case tentative
    case confirmed
    case dying
}

/// Represents a single tracked bounding box with temporal smoothing state.
/// All coordinates are in normalized (0-1) Vision coordinate space.
struct TrackedBox {
    /// Current smoothed bounding box (normalized coordinates)
    var smoothedRect: CGRect
    
    /// Number of consecutive frames this box has been detected
    var consecutiveFrames: Int
    
    /// Number of consecutive frames this box has been missing
    var missedFrames: Int
    
    /// Unique identifier for this track (assigned by tracker)
    let trackId: Int
    
    /// Current state of this track
    var state: TrackState
    
    /// Initialize a new tracked box from a detection
    init(trackId: Int, initialRect: CGRect) {
        self.trackId = trackId
        self.smoothedRect = initialRect
        self.consecutiveFrames = 1
        self.missedFrames = 0
        self.state = .tentative
    }
    
    /// Update the smoothed box using Exponential Moving Average
    /// - Parameters:
    ///   - newRect: The new detection (normalized coordinates)
    ///   - alpha: Smoothing factor (0-1), higher = more responsive
    mutating func updateWithEMA(newRect: CGRect, alpha: Double) {
        let x = alpha * Double(newRect.origin.x) + (1.0 - alpha) * Double(smoothedRect.origin.x)
        let y = alpha * Double(newRect.origin.y) + (1.0 - alpha) * Double(smoothedRect.origin.y)
        let width = alpha * Double(newRect.width) + (1.0 - alpha) * Double(smoothedRect.width)
        let height = alpha * Double(newRect.height) + (1.0 - alpha) * Double(smoothedRect.height)
        
        smoothedRect = CGRect(
            x: x,
            y: y,
            width: width,
            height: height
        )
        
        consecutiveFrames += 1
        missedFrames = 0
    }
    
    /// Reset smoothing state (used when box jumps too far)
    mutating func reset(newRect: CGRect) {
        smoothedRect = newRect
        consecutiveFrames = 1
        missedFrames = 0
    }
    
    /// Mark this box as missed in the current frame
    mutating func markMissed() {
        missedFrames += 1
        // Reset consecutiveFrames when missed - it represents the CURRENT consecutive streak
        // This ensures noise filtering works correctly (single-frame detections are filtered)
        consecutiveFrames = 0
    }
}

