//
//  CameraService.swift
//  CloverFinder
//
//  Created by Pawel Sikora on 19/12/2025.
//

@preconcurrency import AVFoundation
import Combine
import CoreMedia

final class CameraService: NSObject, ObservableObject {
    
    //session vars
    @Published var isAuthorized: Bool = false
    let session = AVCaptureSession()
    
    //frame capture vars
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sampleBufferQueue = DispatchQueue(
        label: "camera.sample.buffer.queue",
        qos: .userInitiated
    )
    private let framePipeline = FramePipeline(analyzeEveryNthFrame: 2) //1 is super costy
    private let analyzer = FrameAnalyzer()

    func configure() async {
        let authorized = await requestAuthorizationIfNeeded()
        isAuthorized = authorized
        guard authorized else { return }

        session.beginConfiguration()
        session.sessionPreset = .high
        
        videoOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA
        ]

        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        framePipeline.output = self
        
        
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
    
    func setAnalyzerOutput(_ output: FrameAnalyzerOutput) {
        analyzer.output = output
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

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    
     func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        framePipeline.ingest(sampleBuffer)
    }

}

extension CameraService: FramePipelineOutput {
    
    func pipelineDidSelectFrame(_ sampleBuffer: CMSampleBuffer) {
        Task.detached(priority: .userInitiated) { [analyzer] in
            await analyzer.analyze(sampleBuffer)
        }
    }
    
}
