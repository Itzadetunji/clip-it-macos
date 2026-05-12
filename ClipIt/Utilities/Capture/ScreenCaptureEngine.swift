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
    private let screenHandlerQueue = DispatchQueue(label: "clipit.sck.screen", qos: .userInitiated)
    private let audioHandlerQueue = DispatchQueue(label: "clipit.sck.system-audio", qos: .userInitiated)
    private let output = ClipCaptureOutput()
    private let streamDelegate = ClipStreamDelegate()

    func start() async throws {
        guard stream == nil else { throw ScreenCaptureEngineError.alreadyRunning }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = content.displays.first else { throw ScreenCaptureEngineError.noDisplay }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        let scale = NSScreen.main?.backingScaleFactor
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

        let stream = SCStream(filter: filter, configuration: configuration, delegate: streamDelegate)
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: screenHandlerQueue)
        try stream.addStreamOutput(output, type: .audio, sampleHandlerQueue: audioHandlerQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async throws {
        guard let stream else { return }
        try await stream.stopCapture()
        self.stream = nil
    }
}
