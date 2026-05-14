//
//  ScreenCaptureEngine.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 12/05/2026.
//

import AppKit
import CoreMedia
import ScreenCaptureKit

enum ScreenCaptureEngineError: Error {
    case noDisplay
    case alreadyRunning
}

@MainActor
final class ScreenCaptureEngine {
    private var stream: SCStream?
    private let sampleHandlerQueue = DispatchQueue(label: "clipit.sck.samples", qos: .userInitiated)
    private let output: ClipCaptureOutput
    private let streamDelegate = ClipStreamDelegate()
    init(rollingBufferRecorder: RollingBufferRecorder) {
        self.output = ClipCaptureOutput(recorder: rollingBufferRecorder)
    }

    func start(includeMicrophone: Bool) async throws {
        guard stream == nil else {
            throw ScreenCaptureEngineError.alreadyRunning
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )
        guard let display = content.displays.first else {
            throw ScreenCaptureEngineError.noDisplay
        }

        let filter = SCContentFilter(
            display: display,
            excludingApplications: [],
            exceptingWindows: []
        )

        let scale =
            NSScreen.main?.backingScaleFactor
            ?? NSScreen.screens.first?.backingScaleFactor
            ?? 2.0
        let frame = display.frame
        let pixelWidth = max(1, Int((frame.width * scale).rounded()))
        let pixelHeight = max(1, Int((frame.height * scale).rounded()))

        let configuration = SCStreamConfiguration()
        configuration.width = pixelWidth
        configuration.height = pixelHeight
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = true
        configuration.capturesAudio = true
        configuration.captureMicrophone = includeMicrophone

        let stream = SCStream(
            filter: filter,
            configuration: configuration,
            delegate: streamDelegate
        )
        try stream.addStreamOutput(
            output,
            type: .screen,
            sampleHandlerQueue: sampleHandlerQueue
        )
        try stream.addStreamOutput(
            output,
            type: .audio,
            sampleHandlerQueue: sampleHandlerQueue
        )
        if includeMicrophone {
            try stream.addStreamOutput(
                output,
                type: .microphone,
                sampleHandlerQueue: sampleHandlerQueue
            )
        }
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async throws {
        guard let stream else { return }
        do {
            try await stream.stopCapture()
        } catch {
            print(error)
        }
        self.stream = nil
    }
}
