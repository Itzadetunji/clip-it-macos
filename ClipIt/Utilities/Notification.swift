//
//  Notification.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//
import UserNotifications

/// Delivered immediately (no trigger) so the "Clip Saved" banner appears as soon as the file is written.
func scheduleNotification(title: String, body: String) {

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
    )

    UNUserNotificationCenter.current().add(request)
}
