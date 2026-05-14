//
//  RollingBufferRecorder.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//

import AVFoundation
import CoreMedia
import Foundation

/// Owns 1s rolling segment writers (video + system audio). All mutating work runs on `rollingQueue`.
final class RollingBufferRecorder {
    private let rollingQueue = DispatchQueue(label: "clipit.rolling-buffer", qos: .userInitiated)
    private let saveStateLock = NSLock()
    private var isSavingClip = false

    private var segments: [SegmentMetadata] = []
    private var isSessionActive = false

    private var currentWriter: AVAssetWriter?
    private var currentVideoInput: AVAssetWriterInput?
    private var currentAudioInput: AVAssetWriterInput?
    private var currentSegmentURL: URL?
    private var currentSegmentStartTime: CMTime?
    private var currentSegmentLastVideoTime: CMTime?
    private var preVideoAudioBuffers: [CMSampleBuffer] = []

    // MARK: - Lifecycle

    func beginSession() async {
        await withCheckedContinuation { cont in
            rollingQueue.async {
                RollingSegmentsDirectory.removeAllRollingSegmentFiles()
                self.segments.removeAll()
                self.resetCurrentSegmentWriter()
                self.preVideoAudioBuffers.removeAll()
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
                self.preVideoAudioBuffers.removeAll()
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
            self?._ingestSystemAudio(copy)
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
        _ = videoInput.append(sampleBuffer)
        currentSegmentLastVideoTime = sampleTime
    }

    private func _ingestSystemAudio(_ sampleBuffer: CMSampleBuffer) {
        guard isSessionActive else { return }

        if currentWriter == nil || currentSegmentStartTime == nil {
            preVideoAudioBuffers.append(sampleBuffer)
            if preVideoAudioBuffers.count > 200 {
                preVideoAudioBuffers.removeFirst(preVideoAudioBuffers.count - 200)
            }
            return
        }

        guard let audioInput = currentAudioInput, audioInput.isReadyForMoreMediaData else { return }
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
        try? FileManager.default.removeItem(at: segmentURL)

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
            let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput.expectsMediaDataInRealTime = true
            if writer.canAdd(audioInput) {
                writer.add(audioInput)
            }

            currentWriter = writer
            currentVideoInput = videoInput
            currentAudioInput = audioInput
            currentSegmentURL = segmentURL
        } catch {
            currentWriter = nil
        }
    }

    private func flushPreVideoAudioBuffers() {
        guard let audioInput = currentAudioInput else {
            preVideoAudioBuffers.removeAll()
            return
        }
        for buf in preVideoAudioBuffers {
            if audioInput.isReadyForMoreMediaData {
                _ = audioInput.append(buf)
            }
        }
        preVideoAudioBuffers.removeAll()
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
        currentAudioInput?.markAsFinished()

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
        currentAudioInput = nil
        currentSegmentURL = nil
        currentSegmentStartTime = nil
        currentSegmentLastVideoTime = nil
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
