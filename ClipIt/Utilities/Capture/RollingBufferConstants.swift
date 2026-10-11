//
//  RollingBufferConstants.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//

import AVFoundation
import CoreMedia
import Foundation

nonisolated enum RollingBufferConstants {
    static let segmentDurationSeconds: Double = 1.0
    static let rollingWindowSeconds: Double = 120.0
    static let cmTimeScale: CMTimeScale = 600
    /// How often the last frame is repeated while the screen is still (ScreenCaptureKit sends nothing new then).
    static let stillFrameInterval: Double = 0.1

    static let systemAudioBitRate = 128_000
    static let microphoneBitRate = 96_000

    /// Screen content compresses well, so these bits-per-pixel values stay sharp while keeping segments small.
    static func videoBitRate(width: Int, height: Int, frameRate: Int, codec: AVVideoCodecType) -> Int {
        let bitsPerPixel = codec == .hevc ? 0.06 : 0.1
        let bitRate = Double(width * height * frameRate) * bitsPerPixel
        return Int(min(max(bitRate, 2_000_000), 50_000_000))
    }
}
