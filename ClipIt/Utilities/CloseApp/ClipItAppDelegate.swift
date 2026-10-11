//
//  ClipItAppDelegate.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 12/05/2026.
//

import AppKit
import KeyboardShortcuts

final class ClipItAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        KeyboardShortcuts.onKeyUp(for: .saveClip) {
            Task { @MainActor in
                guard RecordingCoordinator.shared.isRecording else { return }
                do {
                    let viewModel = HomeViewModel.shared
                    let url = try await viewModel.exportRollingClip(
                        durationSeconds: viewModel.userSettings.clipDurationSeconds
                    )
                    print("Saved clip to \(url.path)")
                    scheduleNotification(
                        title: "Clip Saved",
                        body: "Your clip has been saved successfully"
                    )
                } catch {
                    scheduleNotification(
                        title: "Clip Save Failed",
                        body: error.localizedDescription
                    )
                }
            }
        }
    }


    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
