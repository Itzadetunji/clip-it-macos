//
//  MenuBar.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//

import AppKit
import SwiftUI

struct ClipItMenuBarExtra: Scene {
    @State private var viewModel = HomeViewModel.shared

    var body: some Scene {
        MenuBarExtra("Clip It", image: "MenuBarIcon")
        {
            Button {
                openMainWindow()
            } label: {
                Label("Open ClipIt", systemImage: "macwindow")
            }

            Menu("Save Clip") {

                Button("Save 15s") {
                    saveClip(duration: 15)
                }

                Button("Save 30s") {
                    saveClip(duration: 30)
                }

                Button("Save 60s") {
                    saveClip(duration: 60)
                }
            }

            Toggle(
                "Record Microphone",
                isOn: $viewModel.userSettings.recordMicrophone
            )

            Divider()

            Button("Stop Recording") {
                stopRecording()
            }

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

    private func stopRecording() {
        Task { @MainActor in
            do {
                try await RecordingCoordinator.shared.stopCapture()
                viewModel.userSettings.isRecording = false
            } catch {
                scheduleNotification(
                    title: "Stop Recording Failed",
                    body: error.localizedDescription
                )
            }
        }
    }

    private func saveClip(duration: Double) {
        Task {
            @MainActor in
            guard RecordingCoordinator.shared.isRecording else {
                return
            }

            do {
                let url = try await viewModel.exportRollingClip(
                    durationSeconds: duration
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
}
