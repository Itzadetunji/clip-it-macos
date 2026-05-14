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
        return uniqueFileURL(in: dir, prefix: "Segment")
    }

    static func newExportedClipURL(in directory: URL? = nil) throws -> URL {
        let dir: URL
        if let directory {
            dir = directory
        } else {
            dir = try savedClipsURL()
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return uniqueExportedClipURL(in: dir)
    }

    static func removeAllRollingSegmentFiles() {
        guard let dir = try? rollingSegmentsURL() else { return }
        guard let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? FileManager.default.removeItem(at: file)
        }
    }

    private static func uniqueFileURL(in directory: URL, prefix: String) -> URL {
        while true {
            let timestampMicroseconds = UInt64((Date().timeIntervalSince1970 * 1_000_000).rounded())
            let fileName = "\(prefix)-\(timestampMicroseconds)-\(UUID().uuidString).mp4"
            let url = directory.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
    }

    private static func uniqueExportedClipURL(in directory: URL) -> URL {
        let baseName = exportedClipBaseName()
        var candidate = directory.appendingPathComponent("\(baseName).mp4")
        var copyNumber = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent(
                "\(baseName) \(copyNumber).mp4"
            )
            copyNumber += 1
        }

        return candidate
    }

    private static func exportedClipBaseName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return "ClipIt \(formatter.string(from: date))"
    }
}
