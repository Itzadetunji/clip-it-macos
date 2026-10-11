//
//  SegmentedStreamWriter.swift
//  ClipIt
//

import AVFoundation
import CoreMedia
import Foundation
import UniformTypeIdentifiers

/// One long-running `AVAssetWriter` that emits ~1s fragmented-MP4 segments instead of finishing a new file every second.
/// The MPEG4AppleHLS profile allows at most one audio track, so the microphone gets its own instance.
/// Only driven from the recorder's serial queue; the delegate callback touches immutable state only.
nonisolated final class SegmentedStreamWriter: NSObject, AVAssetWriterDelegate, @unchecked Sendable {
    enum Output {
        case initialization(URL)
        case segment(SegmentMetadata)
    }

    private let writer: AVAssetWriter
    private let primaryMediaType: AVMediaType
    private let filePrefix: String
    private let onOutput: (Output) -> Void

    init(
        inputs: [AVAssetWriterInput],
        primaryMediaType: AVMediaType,
        filePrefix: String,
        onOutput: @escaping (Output) -> Void
    ) throws {
        let writer = AVAssetWriter(contentType: UTType(AVFileType.mp4.rawValue)!)
        writer.outputFileTypeProfile = .mpeg4AppleHLS
        writer.preferredOutputSegmentInterval = CMTime(
            seconds: RollingBufferConstants.segmentDurationSeconds,
            preferredTimescale: RollingBufferConstants.cmTimeScale
        )
        for input in inputs {
            guard writer.canAdd(input) else {
                throw RollingBufferError.writerFailed("Could not add \(input.mediaType.rawValue) input to recorder.")
            }
            writer.add(input)
        }

        self.writer = writer
        self.primaryMediaType = primaryMediaType
        self.filePrefix = filePrefix
        self.onOutput = onOutput
        super.init()
        writer.delegate = self
    }

    var isFailed: Bool { writer.status == .failed }

    func start(at time: CMTime) throws {
        writer.initialSegmentStartTime = time
        guard writer.startWriting() else {
            throw writer.error ?? RollingBufferError.writerFailed("Could not start recorder.")
        }
        writer.startSession(atSourceTime: time)
    }

    func cancel() {
        if writer.status == .writing {
            writer.cancelWriting()
        }
    }

    func assetWriter(
        _ writer: AVAssetWriter,
        didOutputSegmentData segmentData: Data,
        segmentType: AVAssetSegmentType,
        segmentReport: AVAssetSegmentReport?
    ) {
        switch segmentType {
        case .initialization:
            guard let url = write(segmentData, prefix: "\(filePrefix)-init") else { return }
            onOutput(.initialization(url))
        case .separable:
            guard let timing = segmentTiming(from: segmentReport),
                  let url = write(segmentData, prefix: filePrefix)
            else { return }
            onOutput(.segment(SegmentMetadata(url: url, startTime: timing.start, endTime: timing.end)))
        @unknown default:
            break
        }
    }

    /// The final flushed segment can report a zero-length primary track; it holds nothing worth keeping.
    private func segmentTiming(from report: AVAssetSegmentReport?) -> CMTimeRange? {
        guard let track = report?.trackReports.first(where: { $0.mediaType == primaryMediaType }),
              track.duration.isValid,
              track.duration > .zero
        else { return nil }
        return CMTimeRange(start: track.earliestPresentationTimeStamp, duration: track.duration)
    }

    private func write(_ data: Data, prefix: String) -> URL? {
        guard let url = try? RollingSegmentsDirectory.newRollingFileURL(prefix: prefix) else { return nil }
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}
