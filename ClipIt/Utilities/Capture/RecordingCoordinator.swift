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

    private let rollingBuffer = RollingBufferRecorder()
    private let screen: ScreenCaptureEngine
    private(set) var isRecording = false

    private init() {
        screen = ScreenCaptureEngine(rollingBufferRecorder: rollingBuffer)
    }

    func startCapture(includeMicrophone: Bool = true) async throws {
        guard !isRecording else { return }
        if includeMicrophone {
            try MicrophoneCapture.validateDefaultInputDevice()
        }
        await rollingBuffer.beginSession()
        do {
            try await screen.start(includeMicrophone: includeMicrophone)
        } catch {
            await rollingBuffer.endSession()
            throw error
        }
        isRecording = true
    }

    func stopCapture() async throws {
        guard isRecording else { return }
        try await screen.stop()
        await rollingBuffer.endSession()
        isRecording = false
    }

    /// Exports the most recent `durationSeconds` of rolling capture to **Application Support/ClipIt/SavedClips**.
    func exportRollingClip(durationSeconds: Double) async throws -> URL {
        try await rollingBuffer.exportLastSeconds(durationSeconds)
    }
}
