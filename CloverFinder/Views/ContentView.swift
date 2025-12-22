//
//  ContentView.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 18/12/2025.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var cameraService = CameraService()
    @StateObject private var detectionViewModel = DetectionViewModel()
    
    var body: some View {
        ZStack {
                CameraPreview(session: cameraService.session)
                    .ignoresSafeArea()

                if !cameraService.isAuthorized {
                    Text("Brak dostępu do kamery")
                        .padding()
                        .background(.black.opacity(0.6))
                        .foregroundColor(.white)
                } else {
                    
                    if let boxes = detectionViewModel.lastResult?.boundingBoxes {
                        BoundingBoxesOverlay(boxes: boxes)
                    }
                    
                    Text(detectionViewModel.lastResultText)
                                    .padding(8)
                                    .background(.black.opacity(0.6))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                                    .padding()
                }
            
                
            }
            .task {
                await cameraService.configure()
                cameraService.setAnalyzerOutput(detectionViewModel)
                cameraService.start()
            }
    }
}

#Preview {
    ContentView()
}
