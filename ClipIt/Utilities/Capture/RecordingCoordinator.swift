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

    func startCapture(includeMicrophone: Bool = true) async throws {
        guard !isRecording else { return }
        await rollingBuffer.beginSession()
        try await screen.start()
        do {
            if includeMicrophone { try microphone.start() }
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

    /// Exports the most recent `durationSeconds` of rolling capture to the user's selected folder.
    func exportRollingClip(
        durationSeconds: Double,
        saveLocation: URL,
        bookmarkData: Data?
    ) async throws -> URL {
        try await SaveLocationAccess.withWritableAccess(
            to: saveLocation,
            bookmarkData: bookmarkData
        ) { destinationDirectory in
            try await rollingBuffer.exportLastSeconds(
                durationSeconds,
                to: destinationDirectory
            )
        }
    }
}
