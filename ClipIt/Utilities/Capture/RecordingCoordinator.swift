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
    private let microphone = MicrophoneCapture()
    private(set) var isRecording = false

    private init() {
        screen = ScreenCaptureEngine(rollingBufferRecorder: rollingBuffer)
    }

    func startCapture(options: CaptureOptions) async throws {
        guard !isRecording else { return }
        await rollingBuffer.beginSession(options: options)
        try await screen.start(options: options)
        do {
            if options.includeMicrophone {
                let rollingBuffer = rollingBuffer
                try microphone.start { sampleBuffer in
                    rollingBuffer.ingestMicrophoneSample(sampleBuffer)
                }
            }
        } catch {
            try? await screen.stop()
            await rollingBuffer.endSession()
            throw error
        }
        isRecording = true
    }

    func stopCapture() async throws {
        guard isRecording else { return }
        try await screen.stop()
        microphone.stop()
        await rollingBuffer.endSession()
        isRecording = false
    }

    /// Writers are configured once per session, so new capture options need a fresh session (this clears the buffer).
    func restartCapture(options: CaptureOptions) async throws {
        guard isRecording else { return }
        try await stopCapture()
        try await startCapture(options: options)
    }

    /// Exports the most recent `durationSeconds` of rolling capture to the user's selected folder.
    func exportRollingClip(
        durationSeconds: Double,
        format: ClipExportFormat,
        saveLocation: URL,
        bookmarkData: Data?
    ) async throws -> URL {
        try await SaveLocationAccess.withWritableAccess(
            to: saveLocation,
            bookmarkData: bookmarkData
        ) { destinationDirectory in
            try await rollingBuffer.exportLastSeconds(
                durationSeconds,
                format: format,
                to: destinationDirectory
            )
        }
    }
}
