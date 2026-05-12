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
}
