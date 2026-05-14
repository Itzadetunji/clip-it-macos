//
//  MenuBar.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//

import AppKit
import SwiftUI

struct ClipItMenuBarExtra: Scene {
    var body: some Scene {
        MenuBarExtra("Clip It", systemImage: "square.and.arrow.down.on.square")
        {
            Button {
                openMainWindow()
            } label: {
                Label("Open ClipIt", systemImage: "macwindow")
            }
            Button("Save 15s") {
                saveClip(duration: 15)
            }
            Button("Save 30s") {
                saveClip(duration: 30)
            }
            Button("Save 60s") {
                saveClip(duration: 60)
            }
            Divider()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit ClipIt", systemImage: "xmark.square")
            }
        }
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
    }

    private func saveClip(duration: Double) {
        Task {
            @MainActor in
            guard RecordingCoordinator.shared.isRecording else {
                return
            }

            do {
                let settings = loadSettings()
                let url = try await RecordingCoordinator.shared
                    .exportRollingClip(
                        durationSeconds: duration,
                        saveLocation: settings.saveLocation
                    )

                print("Saved Clip to \(url.path)")

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

    private func loadSettings() -> Settings {
        guard
            let data = UserDefaults.standard.data(forKey: "user"),
            let settings = try? JSONDecoder().decode(Settings.self, from: data)
        else {
            return Settings()
        }

        return settings
    }
}
