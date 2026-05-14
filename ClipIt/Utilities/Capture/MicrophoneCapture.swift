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

enum MicrophoneCapture {
    static func validateDefaultInputDevice() throws {
        let engine = AVAudioEngine()
        let inputFormat = engine.inputNode.inputFormat(forBus: 0)

        guard inputFormat.channelCount > 0 else {
            throw MicrophoneCaptureError.noInputDevice
        }

        guard inputFormat.sampleRate > 0 else {
            throw MicrophoneCaptureError.invalidInputFormat
        }
    }
}
