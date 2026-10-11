//
//  MenuBar.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//

import AppKit
import KeyboardShortcuts
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

            Divider()

            if viewModel.userSettings.isRecording {
                Button("Stop Recording") {
                    stopRecording()
                }
            } else {
                Button("Start Recording") {
                    startRecording()
                }
            }

            Button(saveCurrentTitle) {
                saveClip(duration: viewModel.userSettings.clipDurationSeconds)
            }
            .disabled(!viewModel.userSettings.isRecording)

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
            .disabled(!viewModel.userSettings.isRecording)

            Toggle(
                "Record Microphone",
                isOn: $viewModel.userSettings.recordMicrophone
            )

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit ClipIt", systemImage: "xmark.square")
            }
        }
    }

    private var saveCurrentTitle: String {
        let seconds = Int(viewModel.userSettings.clipDurationSeconds)
        guard let shortcut = KeyboardShortcuts.getShortcut(for: .saveClip) else {
            return "Clip It (\(seconds)s)"
        }
        return "Clip It (\(seconds)s)   \(shortcut.description)"
    }

    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
    }

    private func startRecording() {
        Task { @MainActor in
            await viewModel.setRecording(true)
            // Start errors are shown as alerts in the main window.
            if !viewModel.userSettings.isRecording {
                openMainWindow()
            }
        }
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
        Task { @MainActor in
            await viewModel.saveClip(durationSeconds: duration, showsErrorAlert: false)
        }
    }
}
