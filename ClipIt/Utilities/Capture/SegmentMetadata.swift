//
//  SegmentMetadata.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//

import CoreMedia
import Foundation

/// One fragmented-MP4 media segment on disk. Times are capture (host clock) timestamps.
nonisolated struct SegmentMetadata {
    let url: URL
    let startTime: CMTime
    let endTime: CMTime
}

/// Everything needed to rebuild a playable file from one segmented stream.
nonisolated struct SegmentedStreamSnapshot {
    let initializationSegmentURL: URL
    let segments: [SegmentMetadata]
}
