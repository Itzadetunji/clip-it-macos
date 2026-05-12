//
//  RecordingCoordinator.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 12/05/2026.
//

import Foundation

@MainActor
final class RecordingCoordinator {
    static let shared = RecordingCoordinator()
    private let screen = ScreenCaptureEngine()
    private let microphone = MicrophoneCapture()
    private(set) var isRecording = false

    func startCapture(includeMicrophone: Bool = true) async throws {
        guard !isRecording else { return }
        try await screen.start()
        do {
            if includeMicrophone { try microphone.start() }
        } catch {
            // Keep internal state consistent if mic setup fails after screen capture starts.
            try? await screen.stop()
            throw error
        }
        isRecording = true
    }
    

    func stopCapture() async throws {
        guard isRecording else { return }
        try await screen.stop()
        microphone.stop()
        isRecording = false
    }
    
}
