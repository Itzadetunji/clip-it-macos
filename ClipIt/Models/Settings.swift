//
//  Settings.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 12/05/2026.
//

import AppKit
import Foundation

struct Settings: Codable, Equatable {
    var launchOnLogin = false
    var StatusBarIcon = false
    var Time: Times = Times.fifteen
    var IsCustom = false
    var CustomTime = 60
    var isRecording = false
    var saveLocation: URL = defaultClipsDirectory()
    var saveLocationBookmarkData: Data?

    /// Resolved clip length in seconds based on user selection.
    /// - If custom is enabled, use `CustomTime` (minimum 1s).
    /// - Otherwise use preset `Time` values (stored in milliseconds).
    var clipDurationSeconds: Double {
        if IsCustom {
            return Double(max(1, CustomTime))
        }
        return Double(Time.rawValue) / 1000.0
    }
}

func defaultClipsDirectory() -> URL {
    let downloadsURL = FileManager.default.urls(
        for: .downloadsDirectory,
        in: .userDomainMask
    ).first!

    let clipsFolder = downloadsURL.appendingPathComponent("Clips")

    try? FileManager.default.createDirectory(
        at: clipsFolder,
        withIntermediateDirectories: true
    )

    return clipsFolder
}

enum Times: Int, Codable {
    case fifteen = 15_000
    case thirty = 30_000
    case sixty = 60_000
}
