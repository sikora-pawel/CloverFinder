//
//  ContentView.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 18/12/2025.
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var cameraService = CameraService()
    
    var body: some View {
        ZStack {
                CameraPreview(session: cameraService.session)
                    .ignoresSafeArea()

                if !cameraService.isAuthorized {
                    Text("Brak dostępu do kamery")
                        .padding()
                        .background(.black.opacity(0.6))
                        .foregroundColor(.white)
                }
            }
            .task {
                await cameraService.configure()
                cameraService.start()
            }
    }
}

#Preview {
    ContentView()
}
