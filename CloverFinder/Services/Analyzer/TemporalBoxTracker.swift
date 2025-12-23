//
//  TemporalBoxTracker.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 22/12/2025.
//

import Foundation
import CoreGraphics

/// Events emitted by the tracker to signal track lifecycle changes.
/// 
/// **Hybrid API Model:**
/// - Events signal discrete lifecycle transitions (appeared, confirmed, lost)
/// - Each lifecycle event is emitted exactly once per track
/// - Continuous geometry updates are NOT events - use getConfirmedTrackRects() instead
enum DetectionEvent {
    /// Emitted exactly once when a new track is created (tentative state)
    case appeared(trackId: Int)
    /// Emitted exactly once when a track transitions from tentative to confirmed
    case confirmed(trackId: Int, rect: CGRect)
    /// Emitted exactly once when a track is removed after being missing too long
    case lost(trackId: Int)
}

/// Tracks multiple bounding boxes over time with temporal smoothing and noise filtering.
/// All operations are performed in normalized (0-1) Vision coordinate space.
///
/// **Hybrid API Design:**
/// - **Events** (via update() return value): Discrete lifecycle transitions only
///   - Use events to react to track creation, confirmation, and removal
///   - Each event type is emitted exactly once per track
/// - **Snapshot** (via getConfirmedTrackRects()): Current geometry for all confirmed tracks
///   - Call this method each frame to get continuously updated rectangle positions
///   - This is the single source of truth for current confirmed track geometry
///   - Geometry updates do NOT generate events
final class TemporalBoxTracker {
    
    // MARK: - Configuration
    
    /// IoU threshold for matching boxes between frames (0-1)
    var iouThreshold: Double = 0.3
    
    /// EMA smoothing factor (0-1). Higher = more responsive, lower = more stable
    var smoothingAlpha: Double = 0.7
    
    /// Minimum consecutive frames a box must appear before being output (noise filtering)
    var minFramesToConfirm: Int = 5
    
    /// Maximum frames a box can be missing before being dropped
    var maxMissedFrames: Int = 5
    
    /// Maximum distance (in normalized coordinates) a box can jump before resetting smoothing
    /// Computed as: max(abs(delta_x), abs(delta_y), abs(delta_width), abs(delta_height))
    var maxJumpDistance: Double = 0.3
    
    // MARK: - State
    
    private var trackedBoxes: [TrackedBox] = []
    private var nextTrackId: Int = 0
    
    // MARK: - Public API
    
    /// Update tracker with new detections from current frame.
    ///
    /// **Returns:** Array of lifecycle events (appeared, confirmed, lost) for this frame.
    /// - Each event type is emitted exactly once per track
    /// - Geometry updates for existing confirmed tracks do NOT generate events
    /// - Use getConfirmedTrackRects() to get current geometry for rendering
    ///
    /// - Parameter detections: Array of bounding boxes in normalized (0-1) coordinates
    /// - Returns: Array of detection events signaling track lifecycle changes
    func update(with detections: [CGRect]) -> [DetectionEvent] {
        var events: [DetectionEvent] = []
        // Match new detections to existing tracks
        var matchedTrackIndices = Set<Int>()
        var matchedDetectionIndices = Set<Int>()
        
        // Match detections to tracks using IoU (with greedy best-match strategy)
        for (detectionIdx, detection) in detections.enumerated() {
            var bestMatch: (trackIdx: Int, iou: Double)?
            
            for (trackIdx, track) in trackedBoxes.enumerated() {
                guard !matchedTrackIndices.contains(trackIdx) else { continue }
                // Exclude .dying tracks from matching to allow reappearing objects to form new tracks
                guard track.state != .dying else { continue }
                
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
                    // Exclude .dying tracks from matching to allow reappearing objects to form new tracks
                    guard track.state != .dying else { continue }
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
                
                // Check if track should transition from tentative to confirmed
                // Emit .confirmed event exactly once when this transition occurs
                let wasTentative = trackedBoxes[match.trackIdx].state == .tentative
                if wasTentative && trackedBoxes[match.trackIdx].consecutiveFrames >= minFramesToConfirm {
                    // State transition: tentative -> confirmed (emit event exactly once)
                    trackedBoxes[match.trackIdx].state = .confirmed
                    events.append(.confirmed(trackId: trackedBoxes[match.trackIdx].trackId, rect: trackedBoxes[match.trackIdx].smoothedRect))
                }
                // Note: Geometry updates for confirmed tracks do NOT emit events
                // Use getConfirmedTrackRects() to get continuously updated positions
            }
        }
        
        // Create new tracks for unmatched detections
        // Emit .appeared event exactly once when a new track is created
        for (detectionIdx, detection) in detections.enumerated() {
            if !matchedDetectionIndices.contains(detectionIdx) {
                let newTrack = TrackedBox(trackId: nextTrackId, initialRect: detection)
                events.append(.appeared(trackId: newTrack.trackId)) // Emit exactly once per new track
                nextTrackId += 1
                trackedBoxes.append(newTrack)
            }
        }
        
        // Mark unmatched tracks as missed (only after matching is complete)
        for i in trackedBoxes.indices {
            if !matchedTrackIndices.contains(i) {
                trackedBoxes[i].markMissed()
                // Transition confirmed tracks to dying when missed
                if trackedBoxes[i].state == .confirmed {
                    trackedBoxes[i].state = .dying
                }
            }
        }
        
        // Remove tracks that have been missing too long and emit lost events
        // Emit .lost event exactly once when a track is removed
        let tracksToRemove = trackedBoxes.filter { $0.missedFrames > maxMissedFrames }
        for track in tracksToRemove {
            events.append(.lost(trackId: track.trackId)) // Emit exactly once per removed track
        }
        trackedBoxes.removeAll { $0.missedFrames > maxMissedFrames }
        
        return events
    }
    
    /// Get current confirmed track rects for rendering.
    ///
    /// **Snapshot API:** This is the single source of truth for current confirmed track geometry.
    /// - Returns continuously updated positions for all confirmed tracks
    /// - Call this method each frame to get the latest smoothed rectangle positions
    /// - Geometry updates do NOT generate events (use update() events for lifecycle changes only)
    ///
    /// - Returns: Dictionary mapping trackId to current smoothed rect for all confirmed tracks
    func getConfirmedTrackRects() -> [Int: CGRect] {
        var result: [Int: CGRect] = [:]
        for track in trackedBoxes {
            if track.state == .confirmed {
                result[track.trackId] = track.smoothedRect
            }
        }
        return result
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

