//
//  RollingBufferRecorder.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//

import AVFoundation
import CoreMedia
import Foundation
import UniformTypeIdentifiers

/// Owns the continuous segmented writers (screen + system audio, and optional microphone).
/// All mutating work runs on `rollingQueue`, which is what makes the unchecked `Sendable` safe.
nonisolated final class RollingBufferRecorder: @unchecked Sendable {
    private let rollingQueue = DispatchQueue(label: "clipit.rolling-buffer", qos: .userInitiated)
    private let saveStateLock = NSLock()
    private var isSavingClip = false

    private var isSessionActive = false
    private var options = CaptureOptions(resolution: .p1440, frameRate: .fps60, includeMicrophone: false)

    /// Bumped on every reset so late callbacks from a cancelled writer are ignored.
    private var screenGeneration = 0
    private var microphoneGeneration = 0

    private var screenStream: SegmentedStreamWriter?
    private var screenVideoInput: AVAssetWriterInput?
    private var systemAudioInput: AVAssetWriterInput?
    private var screenInitURL: URL?
    private var screenSegments: [SegmentMetadata] = []
    private var lastVideoTime: CMTime?
    private var lastScreenSample: CMSampleBuffer?
    private var stillFrameTimer: DispatchSourceTimer?

    private var microphoneStream: SegmentedStreamWriter?
    private var microphoneInput: AVAssetWriterInput?
    private var microphoneInitURL: URL?
    private var microphoneSegments: [SegmentMetadata] = []

    // MARK: - Lifecycle

    func beginSession(options: CaptureOptions) async {
        await withCheckedContinuation { cont in
            rollingQueue.async {
                self.resetAllStreams()
                RollingSegmentsDirectory.removeAllRollingSegmentFiles()
                self.options = options
                self.isSessionActive = true
                self.startStillFrameTimer()
                cont.resume()
            }
        }
    }

    func endSession() async {
        await withCheckedContinuation { cont in
            rollingQueue.async {
                self.isSessionActive = false
                self.stillFrameTimer?.cancel()
                self.stillFrameTimer = nil
                self.resetAllStreams()
                RollingSegmentsDirectory.removeAllRollingSegmentFiles()
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

    func ingestMicrophoneSample(_ sampleBuffer: CMSampleBuffer) {
        guard let copy = Self.copySample(sampleBuffer) else { return }
        rollingQueue.async { [weak self] in
            self?._ingestMicrophone(copy)
        }
    }

    // MARK: - Export

    func exportLastSeconds(
        _ durationSeconds: Double,
        format: ClipExportFormat,
        to destinationDirectory: URL
    ) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            rollingQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: RollingBufferError.noSegments)
                    return
                }
                guard let screenInitURL = self.screenInitURL, !self.screenSegments.isEmpty else {
                    continuation.resume(throwing: RollingBufferError.noSegments)
                    return
                }
                let screen = SegmentedStreamSnapshot(
                    initializationSegmentURL: screenInitURL,
                    segments: self.screenSegments
                )
                let microphone = self.microphoneInitURL.map {
                    SegmentedStreamSnapshot(initializationSegmentURL: $0, segments: self.microphoneSegments)
                }

                guard self.beginSaving() else {
                    continuation.resume(throwing: RollingBufferError.saveInProgress)
                    return
                }

                let outputURL: URL
                do {
                    outputURL = try RollingSegmentsDirectory.newExportedClipURL(in: destinationDirectory)
                } catch {
                    self.endSaving()
                    continuation.resume(throwing: error)
                    return
                }

                Task {
                    do {
                        try await RollingClipExporter.export(
                            screen: screen,
                            microphone: microphone,
                            durationSeconds: durationSeconds,
                            format: format,
                            outputURL: outputURL
                        )
                        self.endSaving()
                        continuation.resume(returning: outputURL)
                    } catch {
                        self.endSaving()
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    private func beginSaving() -> Bool {
        saveStateLock.lock()
        defer { saveStateLock.unlock() }
        guard !isSavingClip else { return false }
        isSavingClip = true
        return true
    }

    private func endSaving() {
        saveStateLock.lock()
        isSavingClip = false
        saveStateLock.unlock()
    }

    private var isSaving: Bool {
        saveStateLock.lock()
        defer { saveStateLock.unlock() }
        return isSavingClip
    }

    // MARK: - Private ingest

    private func _ingestScreen(_ sampleBuffer: CMSampleBuffer) {
        guard isSessionActive else { return }

        let sampleTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if let lastVideoTime, CMTimeCompare(sampleTime, lastVideoTime) <= 0 {
            return
        }

        if screenStream?.isFailed == true {
            resetScreenStream()
        }
        if screenStream == nil {
            startScreenStream(firstSample: sampleBuffer, at: sampleTime)
        }

        guard let videoInput = screenVideoInput, videoInput.isReadyForMoreMediaData else { return }
        if videoInput.append(sampleBuffer) {
            lastVideoTime = sampleTime
            lastScreenSample = sampleBuffer
        }
    }

    /// ScreenCaptureKit sends no new frames while the screen is still. Without video, segments have no keyframe
    /// to start a clip on, so the last frame is repeated until the screen changes again.
    private func startStillFrameTimer() {
        stillFrameTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: rollingQueue)
        timer.schedule(deadline: .now() + RollingBufferConstants.stillFrameInterval, repeating: RollingBufferConstants.stillFrameInterval)
        timer.setEventHandler { [weak self] in
            self?.repeatLastFrameIfStill()
        }
        timer.resume()
        stillFrameTimer = timer
    }

    private func repeatLastFrameIfStill() {
        guard isSessionActive,
              let lastScreenSample,
              let lastVideoTime,
              let videoInput = screenVideoInput,
              videoInput.isReadyForMoreMediaData
        else { return }

        // Stamped slightly in the past so a real frame captured just before this tick isn't rejected as out of order.
        let now = CMClockGetTime(CMClockGetHostTimeClock())
        let repeatTime = CMTimeSubtract(now, CMTime(seconds: RollingBufferConstants.stillFrameInterval / 2, preferredTimescale: 1_000_000))
        let stillThreshold = CMTime(seconds: RollingBufferConstants.stillFrameInterval, preferredTimescale: 1_000_000)
        guard CMTimeCompare(CMTimeSubtract(repeatTime, lastVideoTime), stillThreshold) >= 0 else { return }

        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: repeatTime, decodeTimeStamp: .invalid)
        var repeated: CMSampleBuffer?
        guard CMSampleBufferCreateCopyWithNewTiming(
            allocator: kCFAllocatorDefault,
            sampleBuffer: lastScreenSample,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleBufferOut: &repeated
        ) == noErr, let repeated else { return }

        if videoInput.append(repeated) {
            self.lastVideoTime = repeatTime
        }
    }

    private func _ingestSystemAudio(_ sampleBuffer: CMSampleBuffer) {
        guard isSessionActive, screenStream != nil else { return }
        guard let audioInput = systemAudioInput, audioInput.isReadyForMoreMediaData else { return }
        _ = audioInput.append(sampleBuffer)
    }

    private func _ingestMicrophone(_ sampleBuffer: CMSampleBuffer) {
        guard isSessionActive, options.includeMicrophone else { return }

        if microphoneStream?.isFailed == true {
            resetMicrophoneStream()
        }
        if microphoneStream == nil {
            startMicrophoneStream(at: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        }

        guard let input = microphoneInput, input.isReadyForMoreMediaData else { return }
        _ = input.append(sampleBuffer)
    }

    // MARK: - Stream setup

    private func startScreenStream(firstSample: CMSampleBuffer, at time: CMTime) {
        guard let format = CMSampleBufferGetFormatDescription(firstSample) else { return }
        let dimensions = CMVideoFormatDescriptionGetDimensions(format)
        let width = Int(dimensions.width)
        let height = Int(dimensions.height)

        let videoInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: Self.videoSettings(width: width, height: height, frameRate: options.frameRate.rawValue),
            sourceFormatHint: format
        )
        videoInput.expectsMediaDataInRealTime = true

        let audioInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: Self.aacSettings(channels: 2, bitRate: RollingBufferConstants.systemAudioBitRate)
        )
        audioInput.expectsMediaDataInRealTime = true

        let generation = screenGeneration
        do {
            let stream = try SegmentedStreamWriter(
                inputs: [videoInput, audioInput],
                primaryMediaType: .video,
                filePrefix: "Screen"
            ) { [weak self] output in
                self?.rollingQueue.async { self?.handleScreenOutput(output, generation: generation) }
            }
            try stream.start(at: time)
            screenStream = stream
            screenVideoInput = videoInput
            systemAudioInput = audioInput
        } catch {
            print("ClipIt: failed to start screen recorder: \(error)")
        }
    }

    private func startMicrophoneStream(at time: CMTime) {
        let input = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: Self.aacSettings(channels: 1, bitRate: RollingBufferConstants.microphoneBitRate)
        )
        input.expectsMediaDataInRealTime = true

        let generation = microphoneGeneration
        do {
            let stream = try SegmentedStreamWriter(
                inputs: [input],
                primaryMediaType: .audio,
                filePrefix: "Mic"
            ) { [weak self] output in
                self?.rollingQueue.async { self?.handleMicrophoneOutput(output, generation: generation) }
            }
            try stream.start(at: time)
            microphoneStream = stream
            microphoneInput = input
        } catch {
            print("ClipIt: failed to start microphone recorder: \(error)")
        }
    }

    private static func videoSettings(width: Int, height: Int, frameRate: Int) -> [String: Any] {
        let codec: AVVideoCodecType = hevcEncoderAvailable(width: width, height: height) ? .hevc : .h264
        return [
            AVVideoCodecKey: codec,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: RollingBufferConstants.videoBitRate(
                    width: width,
                    height: height,
                    frameRate: frameRate,
                    codec: codec
                ),
                AVVideoExpectedSourceFrameRateKey: frameRate,
                AVVideoMaxKeyFrameIntervalDurationKey: RollingBufferConstants.segmentDurationSeconds,
                AVVideoAllowFrameReorderingKey: false,
            ],
        ]
    }

    private static func hevcEncoderAvailable(width: Int, height: Int) -> Bool {
        let probe = AVAssetWriter(contentType: UTType(AVFileType.mp4.rawValue)!)
        return probe.canApply(
            outputSettings: [AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: width, AVVideoHeightKey: height],
            forMediaType: .video
        )
    }

    private static func aacSettings(channels: Int, bitRate: Int) -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: bitRate,
        ]
    }

    // MARK: - Segment bookkeeping

    private func handleScreenOutput(_ output: SegmentedStreamWriter.Output, generation: Int) {
        guard isSessionActive, generation == screenGeneration else {
            Self.removeFile(of: output)
            return
        }
        switch output {
        case .initialization(let url):
            screenInitURL = url
        case .segment(let segment):
            screenSegments.append(segment)
            pruneOldSegments()
        }
    }

    private func handleMicrophoneOutput(_ output: SegmentedStreamWriter.Output, generation: Int) {
        guard isSessionActive, generation == microphoneGeneration else {
            Self.removeFile(of: output)
            return
        }
        switch output {
        case .initialization(let url):
            microphoneInitURL = url
        case .segment(let segment):
            microphoneSegments.append(segment)
            pruneOldSegments()
        }
    }

    /// Skipped while a save is stitching files; the next segment catches up.
    private func pruneOldSegments() {
        guard !isSaving else { return }
        let latestEnd = [screenSegments.last?.endTime, microphoneSegments.last?.endTime]
            .compactMap { $0 }
            .max { CMTimeCompare($0, $1) < 0 }
        guard let latestEnd else { return }

        let cutoff = CMTimeSubtract(
            latestEnd,
            CMTime(
                seconds: RollingBufferConstants.rollingWindowSeconds,
                preferredTimescale: RollingBufferConstants.cmTimeScale
            )
        )
        screenSegments = Self.removingSegments(endingBefore: cutoff, from: screenSegments)
        microphoneSegments = Self.removingSegments(endingBefore: cutoff, from: microphoneSegments)
    }

    private static func removingSegments(endingBefore cutoff: CMTime, from segments: [SegmentMetadata]) -> [SegmentMetadata] {
        var kept: [SegmentMetadata] = []
        for segment in segments {
            if CMTimeCompare(segment.endTime, cutoff) < 0 {
                try? FileManager.default.removeItem(at: segment.url)
            } else {
                kept.append(segment)
            }
        }
        return kept
    }

    // MARK: - Reset

    private func resetAllStreams() {
        resetScreenStream()
        resetMicrophoneStream()
    }

    /// A new writer produces a new initialization segment, so earlier segments can't be stitched with it.
    private func resetScreenStream() {
        screenGeneration += 1
        screenStream?.cancel()
        screenStream = nil
        screenVideoInput = nil
        systemAudioInput = nil
        lastVideoTime = nil
        lastScreenSample = nil
        screenInitURL.map { try? FileManager.default.removeItem(at: $0) }
        screenInitURL = nil
        screenSegments.forEach { try? FileManager.default.removeItem(at: $0.url) }
        screenSegments.removeAll()
    }

    private func resetMicrophoneStream() {
        microphoneGeneration += 1
        microphoneStream?.cancel()
        microphoneStream = nil
        microphoneInput = nil
        microphoneInitURL.map { try? FileManager.default.removeItem(at: $0) }
        microphoneInitURL = nil
        microphoneSegments.forEach { try? FileManager.default.removeItem(at: $0.url) }
        microphoneSegments.removeAll()
    }

    private static func removeFile(of output: SegmentedStreamWriter.Output) {
        switch output {
        case .initialization(let url):
            try? FileManager.default.removeItem(at: url)
        case .segment(let segment):
            try? FileManager.default.removeItem(at: segment.url)
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
