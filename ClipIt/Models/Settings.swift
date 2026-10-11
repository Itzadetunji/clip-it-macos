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
    var recordMicrophone = false
    var captureResolution: CaptureResolution = .p1440
    var captureFrameRate: CaptureFrameRate = .fps60
    var exportFormat: ClipExportFormat = .hevc

    /// Resolved clip length in seconds based on user selection.
    /// - If custom is enabled, use `CustomTime` (minimum 1s).
    /// - Otherwise use preset `Time` values (stored in milliseconds).
    var clipDurationSeconds: Double {
        if IsCustom {
            return Double(max(1, CustomTime))
        }
        return Double(Time.rawValue) / 1000.0
    }

    var captureOptions: CaptureOptions {
        CaptureOptions(
            resolution: captureResolution,
            frameRate: captureFrameRate,
            includeMicrophone: recordMicrophone
        )
    }
}

extension Settings {
    /// Missing keys fall back to defaults so settings saved by older versions still load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Settings()
        launchOnLogin = try container.decodeIfPresent(Bool.self, forKey: .launchOnLogin) ?? defaults.launchOnLogin
        StatusBarIcon = try container.decodeIfPresent(Bool.self, forKey: .StatusBarIcon) ?? defaults.StatusBarIcon
        Time = try container.decodeIfPresent(Times.self, forKey: .Time) ?? defaults.Time
        IsCustom = try container.decodeIfPresent(Bool.self, forKey: .IsCustom) ?? defaults.IsCustom
        CustomTime = try container.decodeIfPresent(Int.self, forKey: .CustomTime) ?? defaults.CustomTime
        isRecording = try container.decodeIfPresent(Bool.self, forKey: .isRecording) ?? defaults.isRecording
        saveLocation = try container.decodeIfPresent(URL.self, forKey: .saveLocation) ?? defaults.saveLocation
        saveLocationBookmarkData = try container.decodeIfPresent(Data.self, forKey: .saveLocationBookmarkData)
        recordMicrophone = try container.decodeIfPresent(Bool.self, forKey: .recordMicrophone) ?? defaults.recordMicrophone
        captureResolution = try container.decodeIfPresent(CaptureResolution.self, forKey: .captureResolution) ?? defaults.captureResolution
        captureFrameRate = try container.decodeIfPresent(CaptureFrameRate.self, forKey: .captureFrameRate) ?? defaults.captureFrameRate
        exportFormat = try container.decodeIfPresent(ClipExportFormat.self, forKey: .exportFormat) ?? defaults.exportFormat
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

/// Maximum recorded height; the display's aspect ratio is preserved and smaller displays are never upscaled.
nonisolated enum CaptureResolution: String, Codable, CaseIterable, Identifiable {
    case native
    case p1440
    case p1080
    case p720

    var id: String { rawValue }

    var label: String {
        switch self {
        case .native: return "Native"
        case .p1440: return "1440p"
        case .p1080: return "1080p"
        case .p720: return "720p"
        }
    }

    var maxHeight: Int? {
        switch self {
        case .native: return nil
        case .p1440: return 1440
        case .p1080: return 1080
        case .p720: return 720
        }
    }
}

nonisolated enum CaptureFrameRate: Int, Codable, CaseIterable, Identifiable {
    case fps30 = 30
    case fps60 = 60

    var id: Int { rawValue }
    var label: String { "\(rawValue) fps" }
}

nonisolated enum ClipExportFormat: String, Codable, CaseIterable, Identifiable {
    /// Copies the recorded HEVC stream as-is (near-instant).
    case hevc
    /// Re-encodes to H.264 for players and sites without HEVC support (slower).
    case h264

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hevc: return "HEVC (smaller, instant)"
        case .h264: return "H.264 (most compatible)"
        }
    }
}

nonisolated struct CaptureOptions: Equatable {
    var resolution: CaptureResolution
    var frameRate: CaptureFrameRate
    var includeMicrophone: Bool
}
