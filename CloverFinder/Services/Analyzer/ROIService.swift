//
//  ROIService.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 22/12/2025.
//

import Foundation
import CoreVideo
import CoreImage
import CoreGraphics
import ImageIO
import Vision
import Combine

/// ROI extraction service following exact Vision coordinate handling requirements.
/// 
/// **Key Requirements:**
/// 1. Uses the SAME orientation as Vision
/// 2. Orients the image FIRST, then crops
/// 3. Uses VNImageRectForNormalizedRect to convert normalized rects
/// 4. No manual y-flips - coordinate spaces are made consistent through orientation
@MainActor
final class ROIService: ObservableObject {
    
    /// Shared CIContext for rendering (reused for performance)
    /// CIContext is thread-safe, so it can be accessed from nonisolated functions
    private let ciContext: CIContext
    
    /// Current ROI thumbnails by trackId
    @Published private(set) var roiThumbnails: [Int: CGImage] = [:]
    
    /// Selected trackId for verification mode
    @Published var selectedTrackIdForVerification: Int?
    
    /// Frame counter for throttling (accessed from MainActor)
    private var frameCounter: Int = 0
    private let throttleFrames: Int = 5
    
    init() {
        // Create shared CIContext with default options (uses GPU if available)
        ciContext = CIContext(options: nil)
    }
    
    /// Extract ROI from pixelBuffer using the exact same orientation as Vision.
    /// 
    /// **Implementation steps (must follow exactly):**
    /// 1. Create CIImage from CVPixelBuffer
    /// 2. Apply orientation FIRST using oriented(forExifOrientation:)
    /// 3. Convert normalized Vision rect to pixel rect using VNImageRectForNormalizedRect
    /// 4. Crop the oriented image
    /// 5. Render to CGImage
    ///
    /// - Parameters:
    ///   - pixelBuffer: The source CVPixelBuffer
    ///   - normalizedRect: Bounding box in normalized (0-1) Vision coordinates (origin bottom-left)
    ///   - visionOrientation: The exact CGImagePropertyOrientation used by VNImageRequestHandler
    /// - Returns: Cropped CGImage matching what the bounding box overlays in preview, or nil on error
    nonisolated func extractROI(
        from pixelBuffer: CVPixelBuffer,
        normalizedRect: CGRect,
        visionOrientation: CGImagePropertyOrientation
    ) -> CGImage? {
        // Step 1: Create CIImage from CVPixelBuffer
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Step 2: Apply orientation FIRST (using the same orientation as Vision)
        let oriented = ci.oriented(forExifOrientation: Int32(visionOrientation.rawValue))
        
        // Step 3: Get extent of oriented image and convert normalized Vision rect to pixel rect
        let extent = oriented.extent
        var pixelRect = VNImageRectForNormalizedRect(
            normalizedRect,
            Int(extent.width),
            Int(extent.height)
        )
        
        // Clamp pixelRect to extent to avoid out-of-bounds
        pixelRect = pixelRect.intersection(extent)
        guard !pixelRect.isNull && !pixelRect.isEmpty else {
            return nil
        }
        
        // Step 4: Crop using Core Image coordinates (consistent space)
        let cropped = oriented.cropped(to: pixelRect)
        
        // Step 5: Render to CGImage using shared CIContext
        guard let cgImage = ciContext.createCGImage(cropped, from: cropped.extent) else {
            return nil
        }
        
        return cgImage
    }
    
    /// Process frame with confirmed tracks for ROI extraction (throttled).
    /// - Parameters:
    ///   - pixelBuffer: The current frame pixel buffer
    ///   - confirmedTracks: Dictionary mapping trackId to normalized rect
    ///   - visionOrientation: The exact orientation used by Vision
    func processFrame(
        pixelBuffer: CVPixelBuffer,
        confirmedTracks: [Int: CGRect],
        visionOrientation: CGImagePropertyOrientation
    ) {
        frameCounter += 1
        
        // Throttle: only process every Nth frame
        guard frameCounter % throttleFrames == 0 else {
            return
        }
        
        // Extract ROI for each confirmed track (on background thread for performance)
        Task.detached { [weak self, pixelBuffer, confirmedTracks, visionOrientation] in
            guard let self = self else { return }
            
            // Get selected trackId for verification (read from MainActor)
            let selectedId = await self.selectedTrackIdForVerification
            
            // Build thumbnails dictionary using Dictionary(uniqueKeysWithValues:) to avoid mutable capture
            let thumbnailPairs = confirmedTracks.compactMap { (trackId, normalizedRect) -> (Int, CGImage)? in
                // Verification mode: log pixel rect for selected track
                if trackId == selectedId {
                    if let pixelRect = self.getPixelRectForVerification(
                        normalizedRect: normalizedRect,
                        pixelBuffer: pixelBuffer,
                        visionOrientation: visionOrientation
                    ) {
                        print("[ROI Verification] Track \(trackId):")
                        print("  Normalized rect: \(normalizedRect)")
                        print("  Pixel rect (oriented space): \(pixelRect)")
                        print("  Orientation: \(visionOrientation.rawValue)")
                    }
                }
                
                guard let roiImage = self.extractROI(
                    from: pixelBuffer,
                    normalizedRect: normalizedRect,
                    visionOrientation: visionOrientation
                ) else {
                    return nil
                }
                
                return (trackId, roiImage)
            }
            
            let finalThumbnails = Dictionary(uniqueKeysWithValues: thumbnailPairs)
            
            // Update UI on main thread
            await MainActor.run {
                self.roiThumbnails = finalThumbnails
            }
        }
    }
    
    /// Get pixel rect for verification mode (for selected trackId).
    /// Returns the pixel rect that would be used for cropping, in oriented image space.
    /// - Parameters:
    ///   - normalizedRect: The normalized Vision rect
    ///   - pixelBuffer: The source pixel buffer
    ///   - visionOrientation: The exact orientation used by Vision
    /// - Returns: The pixel rect in oriented image coordinates, or nil on error
    nonisolated func getPixelRectForVerification(
        normalizedRect: CGRect,
        pixelBuffer: CVPixelBuffer,
        visionOrientation: CGImagePropertyOrientation
    ) -> CGRect? {
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        let oriented = ci.oriented(forExifOrientation: Int32(visionOrientation.rawValue))
        let extent = oriented.extent
        
        var pixelRect = VNImageRectForNormalizedRect(
            normalizedRect,
            Int(extent.width),
            Int(extent.height)
        )
        
        pixelRect = pixelRect.intersection(extent)
        guard !pixelRect.isNull && !pixelRect.isEmpty else {
            return nil
        }
        
        return pixelRect
    }
}
