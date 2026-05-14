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
                    let settings = self.loadSettings()
                    let url = try await RecordingCoordinator.shared.exportRollingClip(
                        durationSeconds: settings.clipDurationSeconds
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
    
    private func loadSettings() -> Settings {
        guard
            let data = UserDefaults.standard.data(forKey: "user"),
            let settings = try? JSONDecoder().decode(Settings.self, from: data)
        else {
            return Settings()
        }

        return settings
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
