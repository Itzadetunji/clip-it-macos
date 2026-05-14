//
//  RollingClipExporterswift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//

import AVFoundation
import CoreMedia
import Foundation

enum RollingClipExporter {
    /// Stitches overlapping rolling segments into one MP4 (video + first audio track per segment = system audio).
    static func export(
        segments snapshot: [SegmentMetadata],
        durationSeconds: Double,
        outputURL: URL
    ) async throws {
        guard let latest = snapshot.last else {
            throw RollingBufferError.noSegments
        }

        let windowEnd = latest.endTime
        let windowStart = CMTimeSubtract(
            windowEnd,
            CMTime(seconds: durationSeconds, preferredTimescale: RollingBufferConstants.cmTimeScale)
        )

        let selected = snapshot.filter { segment in
            CMTimeCompare(segment.endTime, windowStart) > 0
                && CMTimeCompare(segment.startTime, windowEnd) < 0
        }
        guard !selected.isEmpty else {
            throw RollingBufferError.noSegments
        }

        try? FileManager.default.removeItem(at: outputURL)

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw RollingBufferError.writerFailed("Could not create video track.")
        }
        let audioTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        )

        var insertionTime = CMTime.zero
        for segment in selected {
            let asset = AVURLAsset(url: segment.url)
            let duration = try await asset.load(.duration)
            let vTracks = try await asset.loadTracks(withMediaType: .video)
            if let src = vTracks.first {
                try videoTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: src,
                    at: insertionTime
                )
            }
            let aTracks = try await asset.loadTracks(withMediaType: .audio)
            if let src = aTracks.first, let audioTrack {
                try audioTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: duration),
                    of: src,
                    at: insertionTime
                )
            }
            insertionTime = CMTimeAdd(insertionTime, duration)
        }

        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw RollingBufferError.writerFailed("Could not create export session.")
        }
        try await session.export(to: outputURL, as: .mp4)
    }
}
