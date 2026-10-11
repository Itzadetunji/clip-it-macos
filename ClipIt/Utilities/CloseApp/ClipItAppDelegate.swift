//
//  ClipItAppDelegate.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 12/05/2026.
//

import AppKit
import KeyboardShortcuts
import UserNotifications

final class ClipItAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self

        KeyboardShortcuts.onKeyUp(for: .saveClip) {
            Task { @MainActor in
                await HomeViewModel.shared.exportCurrentRollingClip(showsErrorAlert: false)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// macOS hides banners for the frontmost app unless the delegate opts in, which swallowed "Clip Saved" when saving from the window.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
