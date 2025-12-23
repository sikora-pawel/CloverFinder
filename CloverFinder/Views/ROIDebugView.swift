//
//  ROIDebugView.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 22/12/2025.
//

import SwiftUI
import CoreGraphics

/// Debug view showing ROI thumbnails with trackId
struct ROIDebugView: View {
    let roiThumbnails: [Int: CGImage]
    @Binding var selectedTrackId: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            /*Text("ROI Thumbnails")
                .font(.headline)
                .foregroundColor(.white)*/
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(roiThumbnails.keys.sorted()), id: \.self) { trackId in
                        VStack(spacing: 4) {
                            if let cgImage = roiThumbnails[trackId] {
                                Image(uiImage: UIImage(cgImage: cgImage))
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .border(selectedTrackId == trackId ? Color.yellow : Color.clear, width: 3)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 80, height: 80)
                            }
                            
                            /*Text("ID: \(trackId)")
                                .font(.caption)
                                .foregroundColor(.white)*/
                        }
                        .onTapGesture {
                            if selectedTrackId == trackId {
                                selectedTrackId = nil
                            } else {
                                selectedTrackId = trackId
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
}

