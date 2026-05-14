//
//  RollingBufferRecorder.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//

import AVFoundation
import CoreMedia
import Foundation

/// Owns 1s rolling segment writers (video + system audio + microphone audio). All mutating work runs on `rollingQueue`.
final class RollingBufferRecorder {
    private let rollingQueue = DispatchQueue(label: "clipit.rolling-buffer", qos: .userInitiated)
    private let saveStateLock = NSLock()
    private var isSavingClip = false

    private var segments: [SegmentMetadata] = []
    private var isSessionActive = false

    private var currentWriter: AVAssetWriter?
    private var currentVideoInput: AVAssetWriterInput?
    private var currentSystemAudioInput: AVAssetWriterInput?
    private var currentMicrophoneAudioInput: AVAssetWriterInput?
    private var currentSegmentURL: URL?
    private var currentSegmentStartTime: CMTime?
    private var currentSegmentLastVideoTime: CMTime?
    private var preVideoSystemAudioBuffers: [CMSampleBuffer] = []
    private var preVideoMicrophoneAudioBuffers: [CMSampleBuffer] = []

    // MARK: - Lifecycle

    func beginSession() async {
        await withCheckedContinuation { cont in
            rollingQueue.async {
                RollingSegmentsDirectory.removeAllRollingSegmentFiles()
                self.segments.removeAll()
                self.resetCurrentSegmentWriter()
                self.preVideoSystemAudioBuffers.removeAll()
                self.preVideoMicrophoneAudioBuffers.removeAll()
                self.isSessionActive = true
                cont.resume()
            }
        }
    }

    func endSession() async {
        await withCheckedContinuation { cont in
            rollingQueue.async {
                self.isSessionActive = false
                self.finishCurrentSegmentAndRegisterIfPossible()
                self.resetCurrentSegmentWriter()
                self.segments.removeAll()
                RollingSegmentsDirectory.removeAllRollingSegmentFiles()
                self.preVideoSystemAudioBuffers.removeAll()
                self.preVideoMicrophoneAudioBuffers.removeAll()
                cont.resume()
            }
        }
    }

    // MARK: - Ingest (any thread → rollingQueue)

    func ingestScreenSample(_ sampleBuffer: CMSampleBuffer) {
        guard let copy = Self.copySample(sampleBuffer) else { return }
        rollingQueue.async { [weak self] in
            self?._ingestScreen(copy)
        }
    }

    func ingestSystemAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard let copy = Self.copySample(sampleBuffer) else { return }
        rollingQueue.async { [weak self] in
            self?._ingestAudio(copy, source: .system)
        }
    }

    func ingestMicrophoneAudioSample(_ sampleBuffer: CMSampleBuffer) {
        guard let copy = Self.copySample(sampleBuffer) else { return }
        rollingQueue.async { [weak self] in
            self?._ingestAudio(copy, source: .microphone)
        }
    }

    // MARK: - Export

    func exportLastSeconds(_ durationSeconds: Double) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            rollingQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: RollingBufferError.noSegments)
                    return
                }
                let snapshot = self.segments.sorted { CMTimeCompare($0.startTime, $1.startTime) < 0 }
                guard !snapshot.isEmpty else {
                    continuation.resume(throwing: RollingBufferError.noSegments)
                    return
                }

                self.saveStateLock.lock()
                if self.isSavingClip {
                    self.saveStateLock.unlock()
                    continuation.resume(throwing: RollingBufferError.saveInProgress)
                    return
                }
                self.isSavingClip = true
                self.saveStateLock.unlock()

                let outputURL: URL
                do {
                    outputURL = try RollingSegmentsDirectory.newExportedClipURL()
                } catch {
                    self.saveStateLock.lock()
                    self.isSavingClip = false
                    self.saveStateLock.unlock()
                    continuation.resume(throwing: error)
                    return
                }

                Task {
                    do {
                        try await RollingClipExporter.export(
                            segments: snapshot,
                            durationSeconds: durationSeconds,
                            outputURL: outputURL
                        )
                        self.saveStateLock.lock()
                        self.isSavingClip = false
                        self.saveStateLock.unlock()
                        continuation.resume(returning: outputURL)
                    } catch {
                        self.saveStateLock.lock()
                        self.isSavingClip = false
                        self.saveStateLock.unlock()
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    // MARK: - Private ingest

    private func _ingestScreen(_ sampleBuffer: CMSampleBuffer) {
        guard isSessionActive else { return }

        let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if let lastVideoTime = currentSegmentLastVideoTime,
           CMTimeCompare(sampleTime, lastVideoTime) <= 0 {
            return
        }

        if shouldRotateCurrentSegment(at: sampleTime) {
            finishCurrentSegmentAndRegisterIfPossible()
            resetCurrentSegmentWriter()
        }

        ensureWriterConfiguredForVideo(sampleBuffer)
        guard let writer = currentWriter else { return }

        if currentSegmentStartTime == nil {
            writer.startWriting()
            writer.startSession(atSourceTime: sampleTime)
            currentSegmentStartTime = sampleTime
            flushPreVideoAudioBuffers()
        }

        guard let videoInput = currentVideoInput, videoInput.isReadyForMoreMediaData else { return }
        if videoInput.append(sampleBuffer) {
            currentSegmentLastVideoTime = sampleTime
        }
    }

    private func _ingestAudio(_ sampleBuffer: CMSampleBuffer, source: AudioSource) {
        guard isSessionActive else { return }

        let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

        guard currentWriter != nil, let segmentStart = currentSegmentStartTime else {
            bufferAudioUntilMatchingVideoSegment(sampleBuffer, source: source)
            return
        }

        guard audioSampleBelongsToCurrentSegment(sampleTime, segmentStart: segmentStart) else {
            if CMTimeCompare(sampleTime, segmentStart) > 0 {
                bufferAudioUntilMatchingVideoSegment(sampleBuffer, source: source)
            }
            return
        }
        guard let audioInput = audioInput(for: source), audioInput.isReadyForMoreMediaData else { return }
        _ = audioInput.append(sampleBuffer)
    }

    private func shouldRotateCurrentSegment(at sampleTime: CMTime) -> Bool {
        guard let start = currentSegmentStartTime else { return false }
        let elapsed = CMTimeSubtract(sampleTime, start)
        return CMTimeGetSeconds(elapsed) >= RollingBufferConstants.segmentDurationSeconds
    }

    private func ensureWriterConfiguredForVideo(_ sampleBuffer: CMSampleBuffer) {
        guard currentWriter == nil else { return }
        guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }

        let dimensions = CMVideoFormatDescriptionGetDimensions(format)
        let width = Int(dimensions.width)
        let height = Int(dimensions.height)

        let segmentURL: URL
        do {
            segmentURL = try RollingSegmentsDirectory.newRollingSegmentURL()
        } catch {
            return
        }

        do {
            let writer = try AVAssetWriter(outputURL: segmentURL, fileType: .mp4)
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
            ]
            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings, sourceFormatHint: format)
            videoInput.expectsMediaDataInRealTime = true
            guard writer.canAdd(videoInput) else { return }
            writer.add(videoInput)

            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 48_000,
                AVNumberOfChannelsKey: 2,
                AVEncoderBitRateKey: 128_000,
            ]
            let systemAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            systemAudioInput.expectsMediaDataInRealTime = true
            if writer.canAdd(systemAudioInput) {
                writer.add(systemAudioInput)
                currentSystemAudioInput = systemAudioInput
            }

            let microphoneAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            microphoneAudioInput.expectsMediaDataInRealTime = true
            if writer.canAdd(microphoneAudioInput) {
                writer.add(microphoneAudioInput)
                currentMicrophoneAudioInput = microphoneAudioInput
            }

            currentWriter = writer
            currentVideoInput = videoInput
            currentSegmentURL = segmentURL
        } catch {
            currentWriter = nil
        }
    }

    private func flushPreVideoAudioBuffers() {
        flushPreVideoAudioBuffers(for: .system)
        flushPreVideoAudioBuffers(for: .microphone)
    }

    private func flushPreVideoAudioBuffers(for source: AudioSource) {
        guard let audioInput = audioInput(for: source),
              let segmentStart = currentSegmentStartTime else {
            setPreVideoAudioBuffers([], for: source)
            return
        }

        var deferredBuffers: [CMSampleBuffer] = []
        for buf in preVideoAudioBuffers(for: source) {
            let sampleTime = CMSampleBufferGetPresentationTimeStamp(buf)
            guard audioSampleBelongsToCurrentSegment(sampleTime, segmentStart: segmentStart) else {
                if CMTimeCompare(sampleTime, segmentStart) > 0 {
                    deferredBuffers.append(buf)
                }
                continue
            }
            if audioInput.isReadyForMoreMediaData {
                _ = audioInput.append(buf)
            } else {
                deferredBuffers.append(buf)
            }
        }
        setPreVideoAudioBuffers(Array(deferredBuffers.suffix(200)), for: source)
    }

    private func audioSampleBelongsToCurrentSegment(_ sampleTime: CMTime, segmentStart: CMTime) -> Bool {
        guard CMTimeCompare(sampleTime, segmentStart) >= 0 else { return false }
        let elapsed = CMTimeSubtract(sampleTime, segmentStart)
        return CMTimeGetSeconds(elapsed) < RollingBufferConstants.segmentDurationSeconds
    }

    private func bufferAudioUntilMatchingVideoSegment(_ sampleBuffer: CMSampleBuffer, source: AudioSource) {
        switch source {
        case .system:
            preVideoSystemAudioBuffers.append(sampleBuffer)
            if preVideoSystemAudioBuffers.count > 200 {
                preVideoSystemAudioBuffers.removeFirst(preVideoSystemAudioBuffers.count - 200)
            }
        case .microphone:
            preVideoMicrophoneAudioBuffers.append(sampleBuffer)
            if preVideoMicrophoneAudioBuffers.count > 200 {
                preVideoMicrophoneAudioBuffers.removeFirst(preVideoMicrophoneAudioBuffers.count - 200)
            }
        }
    }

    private func finishCurrentSegmentAndRegisterIfPossible() {
        guard let writer = currentWriter,
              let segmentURL = currentSegmentURL,
              let segmentStart = currentSegmentStartTime,
              let segmentEnd = currentSegmentLastVideoTime
        else {
            resetCurrentSegmentWriter()
            return
        }

        currentVideoInput?.markAsFinished()
        currentSystemAudioInput?.markAsFinished()
        currentMicrophoneAudioInput?.markAsFinished()

        let sem = DispatchSemaphore(value: 0)
        writer.finishWriting { sem.signal() }
        _ = sem.wait(timeout: .now() + 15)

        switch writer.status {
        case .completed:
            if FileManager.default.fileExists(atPath: segmentURL.path) {
                segments.append(SegmentMetadata(url: segmentURL, startTime: segmentStart, endTime: segmentEnd))
                pruneOldSegments(referenceTime: segmentEnd)
            }
        case .failed, .cancelled:
            try? FileManager.default.removeItem(at: segmentURL)
            // optional: log writer.error
        default:
            break
        }
    }

    private func pruneOldSegments(referenceTime: CMTime) {
        let cutoff = CMTimeSubtract(
            referenceTime,
            CMTime(
                seconds: RollingBufferConstants.rollingWindowSeconds,
                preferredTimescale: RollingBufferConstants.cmTimeScale
            )
        )
        var kept: [SegmentMetadata] = []
        for segment in segments {
            if CMTimeCompare(segment.endTime, cutoff) < 0 {
                try? FileManager.default.removeItem(at: segment.url)
            } else {
                kept.append(segment)
            }
        }
        segments = kept.sorted { CMTimeCompare($0.startTime, $1.startTime) < 0 }
    }

    private func resetCurrentSegmentWriter() {
        currentWriter = nil
        currentVideoInput = nil
        currentSystemAudioInput = nil
        currentMicrophoneAudioInput = nil
        currentSegmentURL = nil
        currentSegmentStartTime = nil
        currentSegmentLastVideoTime = nil
    }

    private func audioInput(for source: AudioSource) -> AVAssetWriterInput? {
        switch source {
        case .system:
            return currentSystemAudioInput
        case .microphone:
            return currentMicrophoneAudioInput
        }
    }

    private func preVideoAudioBuffers(for source: AudioSource) -> [CMSampleBuffer] {
        switch source {
        case .system:
            return preVideoSystemAudioBuffers
        case .microphone:
            return preVideoMicrophoneAudioBuffers
        }
    }

    private func setPreVideoAudioBuffers(_ buffers: [CMSampleBuffer], for source: AudioSource) {
        switch source {
        case .system:
            preVideoSystemAudioBuffers = buffers
        case .microphone:
            preVideoMicrophoneAudioBuffers = buffers
        }
    }

    private static func copySample(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer? {
        var copy: CMSampleBuffer?
        let status = CMSampleBufferCreateCopy(
            allocator: kCFAllocatorDefault,
            sampleBuffer: sampleBuffer,
            sampleBufferOut: &copy
        )
        guard status == noErr else { return nil }
        return copy
    }
}

private enum AudioSource {
    case system
    case microphone
}
