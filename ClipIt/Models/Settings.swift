//
//  Settings.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 12/05/2026.
//

import Foundation

struct Settings: Codable, Equatable {
    var launchOnLogin = false
    var StatusBarIcon = false
    var Time: Times = Times.fifteen
    var IsCustom = false
    var CustomTime = 60
    var isRecording = false
}


enum Times: Int, Codable {
    case fifteen = 15_000
    case thirty = 30_000
    case sixty = 60_000
}
