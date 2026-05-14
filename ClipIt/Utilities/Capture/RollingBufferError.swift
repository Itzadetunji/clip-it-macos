//
//  RollingBufferError.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//

import Foundation

enum RollingBufferError: LocalizedError {
    case noSegments
    case saveInProgress
    case sampleCopyFailed
    case writerFailed(String)

    var errorDescription: String? {
        switch self {
        case .noSegments: return "Not enough recorded data yet."
        case .saveInProgress: return "A clip export is already in progress."
        case .sampleCopyFailed: return "Could not copy media sample."
        case .writerFailed(let message): return message
        }
    }
}
