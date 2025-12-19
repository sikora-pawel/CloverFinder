//
//  CameraService.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 19/12/2025.
//

@preconcurrency import AVFoundation
import Combine

@MainActor
final class CameraService: ObservableObject {
    @Published var isAuthorized: Bool = false
    let session = AVCaptureSession()

    func configure() async {
        let authorized = await requestAuthorizationIfNeeded()
        isAuthorized = authorized
        guard authorized else { return }

        session.beginConfiguration()
        session.sessionPreset = .high
        defer { session.commitConfiguration() }
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }

        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else { return }
        
        session.addInput(input)
        
        print("Camera configured: \(device.localizedName)")
    }

    func start() {
        guard !session.isRunning else { return }
        
        let session = self.session
        
        DispatchQueue.global(qos: .userInitiated).async {
               session.startRunning()
            print("Starting capture session on background thread")
           }
    }

    func stop() {
        guard session.isRunning else { return }
        
        let session = self.session
        
        DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
    }
}
