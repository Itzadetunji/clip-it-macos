//
//  MicrophoneCapture.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 12/05/2026.
//

import AVFoundation
import CoreMedia

nonisolated enum MicrophoneCaptureError: LocalizedError {
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

nonisolated final class MicrophoneCapture {
    private var engine: AVAudioEngine?
    private var didInstallTap = false
    private var isRunning = false

    /// Called on the audio tap thread with mono PCM stamped on the host clock (same clock as ScreenCaptureKit).
    func start(onSampleBuffer: @escaping @Sendable (CMSampleBuffer) -> Void) throws {
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

        let converter = MicrophoneSampleConverter()

        // Use the node's native format to avoid tap/device mismatch crashes when
        // the default input device changes or is temporarily unavailable.
        input.installTap(onBus: 0, bufferSize: 4096, format: nil) { buffer, time in
            guard time.isHostTimeValid,
                  let sampleBuffer = converter.sampleBuffer(
                      from: buffer,
                      presentationTime: CMClockMakeHostTimeFromSystemUnits(time.hostTime)
                  )
            else { return }
            onSampleBuffer(sampleBuffer)
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

/// Downmixes tap buffers to mono Float32 (keeping the device sample rate) and wraps them in `CMSampleBuffer`s.
nonisolated private final class MicrophoneSampleConverter: @unchecked Sendable {
    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?
    private var formatDescription: CMAudioFormatDescription?

    func sampleBuffer(from buffer: AVAudioPCMBuffer, presentationTime: CMTime) -> CMSampleBuffer? {
        guard let mono = monoBuffer(from: buffer), mono.frameLength > 0 else { return nil }
        return Self.makeSampleBuffer(from: mono, formatDescription: formatDescription, presentationTime: presentationTime)
    }

    private func monoBuffer(from buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        if converter?.inputFormat != buffer.format {
            guard let format = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: buffer.format.sampleRate,
                channels: 1,
                interleaved: true
            ),
                let newConverter = AVAudioConverter(from: buffer.format, to: format)
            else { return nil }
            newConverter.downmix = true
            var description: CMAudioFormatDescription?
            CMAudioFormatDescriptionCreate(
                allocator: kCFAllocatorDefault,
                asbd: format.streamDescription,
                layoutSize: 0,
                layout: nil,
                magicCookieSize: 0,
                magicCookie: nil,
                extensions: nil,
                formatDescriptionOut: &description
            )
            converter = newConverter
            outputFormat = format
            formatDescription = description
        }

        guard let converter, let outputFormat,
              let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: buffer.frameLength)
        else { return nil }
        do {
            try converter.convert(to: output, from: buffer)
        } catch {
            return nil
        }
        return output
    }

    private static func makeSampleBuffer(
        from buffer: AVAudioPCMBuffer,
        formatDescription: CMAudioFormatDescription?,
        presentationTime: CMTime
    ) -> CMSampleBuffer? {
        guard let formatDescription else { return nil }
        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: CMTimeScale(buffer.format.sampleRate)),
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        guard CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription,
            sampleCount: CMItemCount(buffer.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        ) == noErr, let sampleBuffer else { return nil }

        guard CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: buffer.audioBufferList
        ) == noErr else { return nil }
        return sampleBuffer
    }
}
