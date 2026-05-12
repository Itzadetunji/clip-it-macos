//
//  ClipStreamDelegate.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 12/05/2026.
//

import Foundation
import os.log
import ScreenCaptureKit

final class ClipStreamDelegate: NSObject, SCStreamDelegate {
    private let log = Logger(subsystem: "com.adetunji.clip-it-mac", category: "SCStream")

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        log.error("SCStream stopped: \(error.localizedDescription, privacy: .public)")
    }
}
