//
//  Notification.swift
//  ClipIt
//
//  Created by Adetunji Adeyinka on 14/05/2026.
//
import UserNotifications

func scheduleNotification(title: String, body: String) {

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default

    let trigger = UNTimeIntervalNotificationTrigger(
        timeInterval: 1,
        repeats: false
    )

    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: trigger
    )

    UNUserNotificationCenter.current().add(request)
}
