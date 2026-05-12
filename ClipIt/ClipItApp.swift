//
//  clip_it_macApp.swift
//  clip it mac
//
//  Created by Adetunji Adeyinka on 11/05/2026.
//

import SwiftUI
import AppKit

@main
struct ClipItApp: App {
    var body: some Scene {
        WindowGroup {
            ClipIt()
        }.defaultSize(width: 450, height: 200)
            .windowResizability(.contentSize)

        MenuBarExtra("Clip It", systemImage: "square.and.arrow.down.on.square")
        {
            Button {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.forEach { $0.makeKeyAndOrderFront(nil) }
            } label: {
                Label("Open ClipIt", systemImage: "macwindow")
            }
            
            Button("Save 15s") {
                // trigger 15s save — wire to your capture logic / settings
            }

            Button("Save 30s") {
            }

            Button("Save 60s") {
            }

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label:{
                Label("Quit ClipIt", systemImage: "xmark.square")
            }
        }
    }
}
