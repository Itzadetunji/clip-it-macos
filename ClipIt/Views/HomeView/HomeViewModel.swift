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
    @ObservationIgnored @AppStorage("user") private var userData: Data?

    var userSettings = Settings()
    var alertItem: AlertItem?
    var microphoneAlert: TwoButtonAlertItem?

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



    func selectExportFolder() -> Void {

        let panel = NSOpenPanel()

        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"

        let response = panel.runModal()

         if (response == .OK)
             {
                userSettings.saveLocation = panel.url!
            } else {
                userSettings.saveLocation = defaultClipsDirectory()
         }
    }

    @MainActor
    func setRecording(_ enabled: Bool) async {
        if enabled {
            do {
                try await RecordingCoordinator.shared.startCapture(
                    includeMicrophone: true
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
        do {
            try await RecordingCoordinator.shared.startCapture(
                includeMicrophone: false
            )
            userSettings.isRecording = true
        } catch {
            alertItem = AlertContext.captureError(error)
        }
    }

    // MARK: - Clip export

    @MainActor
    func exportCurrentRollingClip() async {
        guard userSettings.isRecording else { return }
        let seconds = userSettings.clipDurationSeconds
        do {
            let url = try await RecordingCoordinator.shared.exportRollingClip(
                durationSeconds: seconds
            )
            print("Saved clip to \(url.path)")
            scheduleNotification(
                title: "Clip Saved",
                body: "Your clip has been saved successfully"
            )
            // Optional: alertItem = … success
        } catch {
            alertItem = AlertContext.captureError(error)
        }
    }
}
