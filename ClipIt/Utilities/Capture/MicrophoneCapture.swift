//
//  MicrophoneCapture.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 12/05/2026.
//

import AVFoundation

enum MicrophoneCaptureError: LocalizedError {
    case noInputDevice
    case invalidInputFormat

    var errorDescription: String? {
        switch self {
        case .noInputDevice:
            return "No default microphone input device is available."
        case .invalidInputFormat:
            return "The microphone format is invalid. Check your input device settings and try again."
        }
    }
}

final class MicrophoneCapture {
    private var engine: AVAudioEngine?
    private var didInstallTap = false
    private var isRunning = false

    func start() throws {
        guard !isRunning else { return }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.inputFormat(forBus: 0)

        guard inputFormat.channelCount > 0 else {
            throw MicrophoneCaptureError.noInputDevice
        }

        guard inputFormat.sampleRate > 0 else {
            throw MicrophoneCaptureError.invalidInputFormat
        }

        // Use the node's native format to avoid tap/device mismatch crashes when
        // the default input device changes or is temporarily unavailable.
        input.installTap(onBus: 0, bufferSize: 4096, format: nil) { buffer, time in
            // Mic PCM — wire to muxer later.
            _ = buffer
            _ = time
        }
        didInstallTap = true

        do {
            try engine.start()
        } catch {
            if didInstallTap {
                input.removeTap(onBus: 0)
                didInstallTap = false
            }
            throw error
        }

        self.engine = engine
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        guard let engine else {
            isRunning = false
            return
        }

        if didInstallTap {
            engine.inputNode.removeTap(onBus: 0)
            didInstallTap = false
        }

        engine.stop()
        engine.reset()
        self.engine = nil
        isRunning = false
    }
}
