//
//  ClipCaptureOutput.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 12/05/2026.
//

import CoreMedia
import Foundation
import ScreenCaptureKit

final class ClipCaptureOutput: NSObject, SCStreamOutput {
    private weak var recorder: RollingBufferRecorder?
    init(recorder: RollingBufferRecorder) {
        self.recorder = recorder
        super.init()
    }
    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of outputType: SCStreamOutputType
    ) {
        switch outputType {
        case .screen:
            recorder?.ingestScreenSample(sampleBuffer)
        case .audio:
            recorder?.ingestSystemAudioSample(sampleBuffer)
        case .microphone:
            break
        @unknown default:
            break
        }
    }

    //    func stream(
    //        _ stream: SCStream,
    //        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
    //        of outputType: SCStreamOutputType
    //    ) {
    //        switch outputType {
    //        case .screen:
    //            handleScreenVideoSampleBuffer(sampleBuffer)
    //        case .audio:
    //            handleSystemAudioSampleBuffer(sampleBuffer)
    //        case .microphone:
    //            return
    //        @unknown default:
    //            break
    //        }
    //    }
    //
    //    private func handleScreenVideoSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
    //        // Video: pixel buffers via CMSampleBuffer — wire encoder / writer later.
    //        _ = sampleBuffer
    //    }
    //
    //    private func handleSystemAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
    //        // System audio CMSampleBuffers — mux with mic later.
    //        _ = sampleBuffer
    //    }
}
