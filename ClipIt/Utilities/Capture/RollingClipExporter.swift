//
//  RollingClipExporter.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//

import AVFoundation
import CoreMedia
import Foundation

nonisolated enum RollingClipExporter {
    /// Stitches the most recent screen segments (video + system audio) and the overlapping microphone
    /// segments into one MP4. Clips start on a segment boundary (a keyframe), so they can run up to ~1s
    /// longer than requested.
    static func export(
        screen: SegmentedStreamSnapshot,
        microphone: SegmentedStreamSnapshot?,
        durationSeconds: Double,
        format: ClipExportFormat,
        outputURL: URL
    ) async throws {
        let selected = latestSegments(in: screen.segments, covering: durationSeconds)
        guard let windowStart = selected.first?.startTime else {
            throw RollingBufferError.noSegments
        }

        var scratchFiles: [URL] = []
        defer { scratchFiles.forEach { try? FileManager.default.removeItem(at: $0) } }

        let screenURL = try stitch(initializationSegment: screen.initializationSegmentURL, segments: selected)
        scratchFiles.append(screenURL)
        let screenAsset = AVURLAsset(url: screenURL)

        let composition = AVMutableComposition()
        guard let sourceVideo = try await screenAsset.loadTracks(withMediaType: .video).first else {
            throw RollingBufferError.writerFailed("Recorded video track is missing.")
        }
        let clipDuration = try await sourceVideo.load(.timeRange).duration
        let clipRange = CMTimeRange(start: .zero, duration: clipDuration)
        let videoStart = CMTimeAdd(windowStart, try await editListOffset(of: sourceVideo))

        for track in try await screenAsset.load(.tracks) {
            try await insert(track, sourceStart: .zero, at: .zero, limit: clipRange, into: composition)
        }

        if let microphone {
            let windowEnd = CMTimeAdd(windowStart, clipDuration)
            let micSegments = microphone.segments.filter {
                CMTimeCompare($0.endTime, windowStart) > 0 && CMTimeCompare($0.startTime, windowEnd) < 0
            }
            if let firstMicSegment = micSegments.first {
                let micURL = try stitch(initializationSegment: microphone.initializationSegmentURL, segments: micSegments)
                scratchFiles.append(micURL)
                let micAsset = AVURLAsset(url: micURL)
                for track in try await micAsset.loadTracks(withMediaType: .audio) {
                    // Each stitched file's timeline starts at 0, so align the mic using capture timestamps.
                    let micStart = CMTimeAdd(firstMicSegment.startTime, try await editListOffset(of: track))
                    let offset = CMTimeSubtract(micStart, videoStart)
                    let sourceStart = offset < .zero ? CMTimeMultiply(offset, multiplier: -1) : .zero
                    let insertAt = offset > .zero ? offset : .zero
                    try await insert(track, sourceStart: sourceStart, at: insertAt, limit: clipRange, into: composition)
                }
            }
        }

        let preset = format == .hevc ? AVAssetExportPresetPassthrough : AVAssetExportPresetHighestQuality
        guard let session = AVAssetExportSession(asset: composition, presetName: preset) else {
            throw RollingBufferError.writerFailed("Could not create export session.")
        }
        try? FileManager.default.removeItem(at: outputURL)
        try await session.export(to: outputURL, as: .mp4)
    }

    /// Newest segments whose combined length reaches `durationSeconds`, oldest first.
    private static func latestSegments(in segments: [SegmentMetadata], covering durationSeconds: Double) -> [SegmentMetadata] {
        let sorted = segments.sorted { CMTimeCompare($0.startTime, $1.startTime) < 0 }
        var selected: [SegmentMetadata] = []
        var total = 0.0
        for segment in sorted.reversed() where total < durationSeconds {
            selected.insert(segment, at: 0)
            total += CMTimeGetSeconds(CMTimeSubtract(segment.endTime, segment.startTime))
        }
        return selected
    }

    /// Segment reports include AAC encoder priming (~44ms) that the file's edit list skips,
    /// so the first audible sample sits this far after the reported segment start.
    private static func editListOffset(of track: AVAssetTrack) async throws -> CMTime {
        let segments = try await track.load(.segments)
        return segments.first { !$0.isEmpty }?.timeMapping.source.start ?? .zero
    }

    private static func stitch(initializationSegment: URL, segments: [SegmentMetadata]) throws -> URL {
        let url = try RollingSegmentsDirectory.newExportScratchURL()
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.write(contentsOf: Data(contentsOf: initializationSegment))
        for segment in segments {
            try handle.write(contentsOf: Data(contentsOf: segment.url))
        }
        return url
    }

    private static func insert(
        _ track: AVAssetTrack,
        sourceStart: CMTime,
        at insertAt: CMTime,
        limit clipRange: CMTimeRange,
        into composition: AVMutableComposition
    ) async throws {
        let sourceRange = try await track.load(.timeRange)
        let start = CMTimeAdd(sourceRange.start, sourceStart)
        let available = CMTimeSubtract(CMTimeRangeGetEnd(sourceRange), start)
        let remaining = CMTimeSubtract(CMTimeRangeGetEnd(clipRange), insertAt)
        let duration = CMTimeMinimum(available, remaining)
        guard duration > .zero,
              let compositionTrack = composition.addMutableTrack(
                  withMediaType: track.mediaType,
                  preferredTrackID: kCMPersistentTrackID_Invalid
              )
        else { return }
        try compositionTrack.insertTimeRange(
            CMTimeRange(start: start, duration: duration),
            of: track,
            at: insertAt
        )
    }
}
