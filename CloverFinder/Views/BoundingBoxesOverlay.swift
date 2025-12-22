//
//  BoundingBoxesOverlay.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 22/12/2025.
//

import SwiftUI
import CoreGraphics

struct BoundingBoxesOverlay: View {
    let boxes: [CGRect]

    var body: some View {
        GeometryReader { geometry in
            let viewSize = geometry.size

            // Na tym etapie na sztywno (typowy format kamery): 16:9
            let imageAspectRatio: CGFloat = 16.0 / 9.0

            let transformation = Self.aspectFillTransform(viewSize: viewSize, imageAspectRatio: imageAspectRatio)

            ZStack {
                ForEach(Array(boxes.enumerated()), id: \.offset) { _, box in
                    // Vision: (0,0) lewy-dół, SwiftUI: (0,0) lewy-góra -> odwracamy Y
                    let rect = CGRect(
                        x: box.minX * transformation.scale - transformation.xOffset,
                        y: (1.0 - box.maxY) * transformation.scale - transformation.yOffset,
                        width: box.width * transformation.scale,
                        height: box.height * transformation.scale
                    )

                    Rectangle()
                        .stroke(Color.red, lineWidth: 2)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
    }
    
    /// Parametry mapowania Vision (0..1) -> View (punkty) dla trybu .resizeAspectFill
    private static func aspectFillTransform(
        viewSize: CGSize,
        imageAspectRatio: CGFloat
    ) -> (scale: CGFloat, xOffset: CGFloat, yOffset: CGFloat) {

        let viewAspectRatio = viewSize.width / viewSize.height

        if imageAspectRatio > viewAspectRatio {
            // Obraz szerszy niż widok -> wypełniamy po wysokości, przycięcie boków
            let scale = viewSize.height
            let scaledWidth = scale * imageAspectRatio
            let xOffset = (scaledWidth - viewSize.width) / 2.0
            return (scale: scale, xOffset: xOffset, yOffset: 0)
        } else {
            // Obraz wyższy niż widok -> wypełniamy po szerokości, przycięcie góra/dół
            let scale = viewSize.width
            let scaledHeight = scale / imageAspectRatio
            let yOffset = (scaledHeight - viewSize.height) / 2.0
            return (scale: scale, xOffset: 0, yOffset: yOffset)
        }
    }
    
    
}
