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
            userSettings = try JSONDecoder().decode(Settings.self, from: userData)
        } catch {
            alertItem = AlertContext.invalidUserData

        }
    }

}
