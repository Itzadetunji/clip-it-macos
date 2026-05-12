//
//  MicrophoneCapture.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 12/05/2026.
//

import AVFoundation

final class MicrophoneCapture {
    private let engine = AVAudioEngine()
    private var isRunning = false

    func start() throws {
        guard !isRunning else { return }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, time in
            // Mic PCM — wire to muxer later.
            _ = buffer
            _ = time
        }
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }
}
