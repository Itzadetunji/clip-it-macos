//
//  HomeViewModel.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 12/05/2026.
//

import Combine
import SwiftUI

@Observable
final class HomeViewModel {
    /// Shared by the main window and the menu bar so toggles stay in sync.
    static let shared = HomeViewModel()

    @ObservationIgnored @AppStorage("user") private var userData: Data?

    var userSettings = Settings() {
        didSet {
            guard !isLoadingSettings, userSettings != oldValue else { return }
            saveChanges()
            if userSettings.captureOptions != oldValue.captureOptions {
                Task { await applyCaptureOptionsChange() }
            }
        }
    }
    var alertItem: AlertItem?
    var microphoneAlert: TwoButtonAlertItem?

    @ObservationIgnored private var isLoadingSettings = false

    private init() {
        retrieveUser()
    }

    //  MARK: Get and Save user

    func saveChanges() {
        do {
            let data = try JSONEncoder().encode(userSettings)
            userData = data
        } catch {
            alertItem = AlertContext.invalidUserData
        }
    }

    func retrieveUser() {
        guard let userData else {
            return
        }

        isLoadingSettings = true
        defer { isLoadingSettings = false }
        do {
            userSettings = try JSONDecoder().decode(
                Settings.self,
                from: userData
            )
            userSettings.isRecording = RecordingCoordinator.shared.isRecording
        } catch {
            alertItem = AlertContext.invalidUserData

        }
    }



    func selectExportFolder() {
        let panel = NSOpenPanel()

        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.directoryURL = userSettings.saveLocation

        let response = panel.runModal()

        guard response == .OK, let selectedURL = panel.url else { return }

        do {
            let bookmarkData = try SaveLocationAccess.bookmarkData(
                for: selectedURL
            )
            try SaveLocationAccess.validateWritableDirectory(selectedURL)
            userSettings.saveLocation = selectedURL
            userSettings.saveLocationBookmarkData = bookmarkData
        } catch {
            alertItem = AlertContext.captureError(error)
        }
    }

    @MainActor
    func setRecording(_ enabled: Bool) async {
        if enabled {
            do {
                try await RecordingCoordinator.shared.startCapture(
                    options: userSettings.captureOptions
                )
                userSettings.isRecording = true
            } catch {
                if case MicrophoneCaptureError.noInputDevice = error {
                    microphoneAlert = AlertContext.noMicrophoneDetected(
                        onContinueWithoutMicrophone: { [weak self] in
                            guard let self else { return }
                            self.microphoneAlert = nil
                            Task {
                                await self.continueRecordingWithoutMicrophone()
                            }
                        },
                        onCancel: { [weak self] in
                            self?.microphoneAlert = nil
                        }
                    )
                } else {
                    alertItem = AlertContext.captureError(error)
                }
            }
        } else {
            do {
                try await RecordingCoordinator.shared.stopCapture()
                userSettings.isRecording = false
            } catch {
                print(error)
                alertItem = AlertContext.captureError(error)
            }
        }
    }

    @MainActor
    func continueRecordingWithoutMicrophone() async {
        var options = userSettings.captureOptions
        options.includeMicrophone = false
        do {
            try await RecordingCoordinator.shared.startCapture(options: options)
            userSettings.isRecording = true
        } catch {
            alertItem = AlertContext.captureError(error)
        }
    }

    /// Resolution, frame rate and microphone are fixed per session, so a live recording restarts with the new options.
    @MainActor
    private func applyCaptureOptionsChange() async {
        guard RecordingCoordinator.shared.isRecording else { return }
        do {
            try await RecordingCoordinator.shared.restartCapture(
                options: userSettings.captureOptions
            )
        } catch {
            userSettings.isRecording = RecordingCoordinator.shared.isRecording
            alertItem = AlertContext.captureError(error)
        }
    }

    // MARK: - Clip export

    @MainActor
    func exportCurrentRollingClip(showsErrorAlert: Bool = true) async {
        await saveClip(
            durationSeconds: userSettings.clipDurationSeconds,
            showsErrorAlert: showsErrorAlert
        )
    }

    /// Shared by the window, menu bar and keyboard shortcut. Errors become an alert in the window,
    /// or a notification when the window may be hidden.
    @MainActor
    func saveClip(durationSeconds: Double, showsErrorAlert: Bool) async {
        guard RecordingCoordinator.shared.isRecording else { return }
        do {
            let url = try await RecordingCoordinator.shared.exportRollingClip(
                durationSeconds: durationSeconds,
                format: userSettings.exportFormat,
                saveLocation: userSettings.saveLocation,
                bookmarkData: userSettings.saveLocationBookmarkData
            )
            print("Saved clip to \(url.path)")
            scheduleNotification(
                title: "Clip Saved",
                body: "\(url.lastPathComponent) was saved to \(url.deletingLastPathComponent().lastPathComponent)."
            )
        } catch {
            if showsErrorAlert {
                alertItem = AlertContext.captureError(error)
            } else {
                scheduleNotification(
                    title: "Clip Save Failed",
                    body: error.localizedDescription
                )
            }
        }
    }
}
