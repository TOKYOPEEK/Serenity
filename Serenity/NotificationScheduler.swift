import Foundation
import UserNotifications

/// Owns all local-notification work so the view model only describes *what* to schedule.
struct NotificationScheduler {
    struct DailyReminder {
        let id: String
        let title: String
        let body: String
        let hour: Int
        let minute: Int
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func scheduleSOSFollowUp() {
        let content = UNMutableNotificationContent()
        content.title = L("notification.sos.title")
        content.body  = L("notification.sos.body")
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "sos_followup", content: content, trigger: trigger)
        )
    }

    /// Replaces the pending requests with the supplied daily reminders.
    func reschedule(_ reminders: [DailyReminder], removingIds: [String]) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: removingIds)
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body  = reminder.body
            content.sound = .default
            var comps = DateComponents()
            comps.hour   = reminder.hour
            comps.minute = reminder.minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }
}
