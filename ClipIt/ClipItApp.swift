//
//  clip_it_macApp.swift
//  clip it mac
//
//  Created by Adetunji Adeyinka on 11/05/2026.
//

import AppKit
import SwiftUI

@main
struct ClipItApp: App {
    @NSApplicationDelegateAdaptor(ClipItAppDelegate.self) private
        var appDelegate

    var body: some Scene {
        WindowGroup {
            ClipIt()
                .background(CloseHidesWindowInstaller())
        }.defaultSize(width: 450, height: 200)
            .windowResizability(.contentSize)

        ClipItMenuBarExtra()
    }
}
