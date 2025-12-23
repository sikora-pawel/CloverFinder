//
//  TemporalBoxTracker.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 22/12/2025.
//

import Foundation
import CoreGraphics

/// Tracks multiple bounding boxes over time with temporal smoothing and noise filtering.
/// All operations are performed in normalized (0-1) Vision coordinate space.
final class TemporalBoxTracker {
    
    // MARK: - Configuration
    
    /// IoU threshold for matching boxes between frames (0-1)
    var iouThreshold: Double = 0.3
    
    /// EMA smoothing factor (0-1). Higher = more responsive, lower = more stable
    var smoothingAlpha: Double = 0.5
    
    /// Minimum consecutive frames a box must appear before being output (noise filtering)
    var minFramesToConfirm: Int = 4
    
    /// Maximum frames a box can be missing before being dropped
    var maxMissedFrames: Int = 5
    
    /// Maximum distance (in normalized coordinates) a box can jump before resetting smoothing
    /// Computed as: max(abs(delta_x), abs(delta_y), abs(delta_width), abs(delta_height))
    var maxJumpDistance: Double = 0.3
    
    // MARK: - State
    
    private var trackedBoxes: [TrackedBox] = []
    private var nextTrackId: Int = 0
    
    // MARK: - Public API
    
    /// Update tracker with new detections from current frame
    /// - Parameter detections: Array of bounding boxes in normalized (0-1) coordinates
    /// - Returns: Array of smoothed, confirmed bounding boxes ready for rendering
    func update(with detections: [CGRect]) -> [CGRect] {
        // Match new detections to existing tracks
        var matchedTrackIndices = Set<Int>()
        var matchedDetectionIndices = Set<Int>()
        
        // Match detections to tracks using IoU (with greedy best-match strategy)
        for (detectionIdx, detection) in detections.enumerated() {
            var bestMatch: (trackIdx: Int, iou: Double)?
            
            for (trackIdx, track) in trackedBoxes.enumerated() {
                guard !matchedTrackIndices.contains(trackIdx) else { continue }
                
                let iou = calculateIoU(detection, track.smoothedRect)
                if iou >= iouThreshold {
                    if let currentBest = bestMatch {
                        if iou > currentBest.iou {
                            bestMatch = (trackIdx, iou)
                        }
                    } else {
                        bestMatch = (trackIdx, iou)
                    }
                }
            }
            
            // If no IoU match found, try nearest-neighbor matching as fallback
            // (only for tracks that were present in the previous frame)
            if bestMatch == nil {
                var nearestMatch: (trackIdx: Int, distance: Double)?
                
                for (trackIdx, track) in trackedBoxes.enumerated() {
                    guard !matchedTrackIndices.contains(trackIdx) else { continue }
                    // Only match tracks that were present last frame (missedFrames == 1 after markMissed)
                    guard track.missedFrames == 1 else { continue }
                    
                    let distance = calculateCenterDistance(detection, track.smoothedRect)
                    if let currentNearest = nearestMatch {
                        if distance < currentNearest.distance {
                            nearestMatch = (trackIdx, distance)
                        }
                    } else {
                        // Use a reasonable distance threshold for nearest-neighbor (normalized coordinates)
                        let maxDistance = 0.2 // ~20% of frame size
                        if distance < maxDistance {
                            nearestMatch = (trackIdx, distance)
                        }
                    }
                }
                
                if let nearest = nearestMatch {
                    bestMatch = (nearest.trackIdx, 0.0) // Use IoU=0 to indicate nearest-neighbor match
                }
            }
            
            if let match = bestMatch {
                matchedTrackIndices.insert(match.trackIdx)
                matchedDetectionIndices.insert(detectionIdx)
                
                // Check if box jumped too far
                let jumpDistance = calculateJumpDistance(
                    from: trackedBoxes[match.trackIdx].smoothedRect,
                    to: detection
                )
                
                if jumpDistance > maxJumpDistance {
                    // Reset smoothing on large jump
                    trackedBoxes[match.trackIdx].reset(newRect: detection)
                } else {
                    // Apply EMA smoothing
                    trackedBoxes[match.trackIdx].updateWithEMA(
                        newRect: detection,
                        alpha: smoothingAlpha
                    )
                }
            }
        }
        
        // Create new tracks for unmatched detections
        for (detectionIdx, detection) in detections.enumerated() {
            if !matchedDetectionIndices.contains(detectionIdx) {
                let newTrack = TrackedBox(trackId: nextTrackId, initialRect: detection)
                nextTrackId += 1
                trackedBoxes.append(newTrack)
            }
        }
        
        // Mark unmatched tracks as missed (only after matching is complete)
        for i in trackedBoxes.indices {
            if !matchedTrackIndices.contains(i) {
                trackedBoxes[i].markMissed()
            }
        }
        
        // Remove tracks that have been missing too long
        trackedBoxes.removeAll { $0.missedFrames > maxMissedFrames }
        
        // Return only confirmed tracks (filter noise)
        // This ensures single-frame detections are never rendered
        return trackedBoxes
            .filter { $0.consecutiveFrames >= minFramesToConfirm }
            .map { $0.smoothedRect }
    }
    
    /// Reset all tracking state (useful for camera restart or major scene changes)
    func reset() {
        trackedBoxes.removeAll()
        nextTrackId = 0
    }
    
    // MARK: - Private Helpers
    
    /// Calculate Intersection over Union (IoU) between two rectangles
    /// - Parameters:
    ///   - rect1: First rectangle (normalized coordinates)
    ///   - rect2: Second rectangle (normalized coordinates)
    /// - Returns: IoU value between 0 and 1
    private func calculateIoU(_ rect1: CGRect, _ rect2: CGRect) -> Double {
        let intersection = rect1.intersection(rect2)
        
        guard !intersection.isNull else {
            return 0.0
        }
        
        let intersectionArea = Double(intersection.width * intersection.height)
        let unionArea = Double(rect1.width * rect1.height + rect2.width * rect2.height) - intersectionArea
        
        guard unionArea > 0 else {
            return 0.0
        }
        
        return intersectionArea / unionArea
    }
    
    /// Calculate maximum jump distance between two rectangles
    /// Used to detect sudden large movements that should reset smoothing
    /// - Parameters:
    ///   - from: Source rectangle (normalized coordinates)
    ///   - to: Destination rectangle (normalized coordinates)
    /// - Returns: Maximum absolute difference in any dimension
    private func calculateJumpDistance(from: CGRect, to: CGRect) -> Double {
        let deltaX = abs(Double(to.origin.x - from.origin.x))
        let deltaY = abs(Double(to.origin.y - from.origin.y))
        let deltaWidth = abs(Double(to.width - from.width))
        let deltaHeight = abs(Double(to.height - from.height))
        
        return max(deltaX, deltaY, deltaWidth, deltaHeight)
    }
    
    /// Calculate center-to-center distance between two rectangles
    /// Used for nearest-neighbor matching when IoU fails
    /// - Parameters:
    ///   - rect1: First rectangle (normalized coordinates)
    ///   - rect2: Second rectangle (normalized coordinates)
    /// - Returns: Euclidean distance between centers
    private func calculateCenterDistance(_ rect1: CGRect, _ rect2: CGRect) -> Double {
        let center1X = Double(rect1.midX)
        let center1Y = Double(rect1.midY)
        let center2X = Double(rect2.midX)
        let center2Y = Double(rect2.midY)
        
        let deltaX = center1X - center2X
        let deltaY = center1Y - center2Y
        
        return sqrt(deltaX * deltaX + deltaY * deltaY)
    }
}

