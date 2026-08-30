import CodexMenuBarCore
import Foundation
import UserNotifications

final class UsageNotificationManager {
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

    func notifyThresholdCrossings(
        previous: CodexUsageSummary?,
        current: CodexUsageSummary,
        threshold: Int
    ) {
        guard let previous else {
            return
        }

        notifyIfCrossed(
            name: "5-hour",
            previous: previous.fiveHour,
            current: current.fiveHour,
            threshold: threshold
        )

        notifyIfCrossed(
            name: "Weekly",
            previous: previous.weekly,
            current: current.weekly,
            threshold: threshold
        )
    }

    private func notifyIfCrossed(
        name: String,
        previous: RateLimitWindow?,
        current: RateLimitWindow?,
        threshold: Int
    ) {
        guard let previous, let current else {
            return
        }

        let thresholdValue = Double(threshold)

        guard previous.remainingPercent > thresholdValue,
              current.remainingPercent <= thresholdValue else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Codex quota running low"
        content.body =
            "\(name) quota has \(Int(current.remainingPercent.rounded()))% remaining."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier:
                "codex-menubar-\(name)-\(current.resetsAt)-\(threshold)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
