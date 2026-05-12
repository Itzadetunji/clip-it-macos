//
//  Alert.swift
//  Appetizers
//
//  Created by Adetunji Adeyinka on 29/04/2026.
//

import Foundation
import SwiftUI

struct AlertItem: Identifiable {
    let id = UUID()
    let title: Text
    let message: Text
    let dismissButton: Alert.Button
}

struct TwoButtonAlertItem: Identifiable {
    let id = UUID()
    let title: Text
    let message: Text
    let primaryButton: Alert.Button
    let secondaryButton: Alert.Button
}

struct AlertContext {

    //MARK: - ALERTS

    static let invalidForm = AlertItem(
        title: Text("Invalid Form"),
        message: Text(
            "An error occured while saving your information"
        ),
        dismissButton: .default(Text("OK"))
    )

    static let userSaveSuccess = AlertItem(
        title: Text("Profile Saved"),
        message: Text(
            "Your profile information was succesfully saved"
        ),
        dismissButton: .default(Text("OK"))
    )

    static let invalidUserData = AlertItem(
        title: Text("Profile Error"),
        message: Text(
            "Your profile information could not be saved or retrieving your profile"
        ),
        dismissButton: .default(Text("OK"))
    )

    static func noMicrophoneDetected(
        onContinueWithoutMicrophone: @escaping () -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> TwoButtonAlertItem {
        TwoButtonAlertItem(
            title: Text("No microphone detected"),
            message: Text(
                """
                No microphone input is available.

                You can still record the screen and system audio, or cancel and connect a microphone in System Settings.
                """
            ),
            primaryButton: .default(
                Text("Continue without microphone"),
                action: onContinueWithoutMicrophone
            ),
            secondaryButton: .cancel(Text("Cancel"), action: onCancel)
        )
    }

    static func captureError(_ error: Error) -> AlertItem {
        print(error)
        return AlertItem(
            title: Text(
                "An Error Occured"
            ),
            message: Text(error.localizedDescription),
            dismissButton: .default(Text("OK"))
        )
    }

}
