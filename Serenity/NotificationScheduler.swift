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

    /// Schedules a one-off proactive insight at the next occurrence of `hour`,
    /// replacing any pending one. Re-armed whenever the app recomputes the
    /// insight, so the text stays fresh. Empty body cancels it.
    func scheduleProactiveInsight(title: String, body: String, hour: Int = 19) {
        let id = "proactive_insight"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard !body.isEmpty else { return }

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = 0
        guard let fire = Calendar.current.nextDate(
            after: Date(), matching: comps, matchingPolicy: .nextTime) else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default
        let interval = max(60, fire.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
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
