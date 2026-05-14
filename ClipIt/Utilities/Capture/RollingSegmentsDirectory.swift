//
//  RollingSegmentsDirectory.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//

import Foundation

enum RollingSegmentsDirectory {
    private static var supportURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClipIt", isDirectory: true)
    }

    static func rollingSegmentsURL() throws -> URL {
        let url = supportURL.appendingPathComponent("RollingSegments", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func savedClipsURL() throws -> URL {
        let url = supportURL.appendingPathComponent("SavedClips", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func newRollingSegmentURL() throws -> URL {
        let dir = try rollingSegmentsURL()
        let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
        return dir.appendingPathComponent("Segment-\(stamp).mp4")
    }

    static func newExportedClipURL() throws -> URL {
        let dir = try savedClipsURL()
        let stamp = String(format: "%.3f", Date().timeIntervalSince1970)
        return dir.appendingPathComponent("Clip-\(stamp).mp4")
    }

    static func removeAllRollingSegmentFiles() {
        guard let dir = try? rollingSegmentsURL() else { return }
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
