import CodexMenuBarCore
import Foundation
import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var preferences:
        PreferencesStore

    var body: some View {
        HStack(spacing: 4) {
            Image(
                systemName:
                    "gauge.with.dots.needle.67percent"
            )

            if !menuBarText.isEmpty {
                Text(menuBarText)
                    .monospacedDigit()
            }
        }
        .help(
            store.errorMessage
                ?? "Codex usage \(preferences.primaryLabel)"
        )
    }

    private var menuBarText: String {
        guard let summary = store.summary else {
            return preferences
                .menuBarDisplayMode
                == .iconOnly
                ? ""
                : "Codex"
        }

        let fiveHour =
            summary.fiveHour.map {
                "\(percentage(preferences.percentage(for: $0)))%"
            }

        let weekly =
            summary.weekly.map {
                "W\(percentage(preferences.percentage(for: $0)))%"
            }

        let credits =
            preferences.showCreditsInMenuBar
                ? summary.credits.flatMap(
                    menuBarCreditsText
                )
                : nil

        switch preferences
            .menuBarDisplayMode
        {
        case .both:
            return [fiveHour, weekly, credits]
                .compactMap { $0 }
                .joined(separator: " · ")

        case .fiveHour:
            return [fiveHour ?? "—", credits]
                .compactMap { $0 }
                .joined(separator: " · ")

        case .weekly:
            return [weekly ?? "W—", credits]
                .compactMap { $0 }
                .joined(separator: " · ")

        case .iconOnly:
            return ""
        }
    }

    private func menuBarCreditsText(
        _ credits: CodexCredits
    ) -> String? {
        guard credits.hasCredits else {
            return nil
        }

        if credits.unlimited {
            return "∞"
        }

        guard let balance = credits.balance else {
            return nil
        }

        if let value = Double(balance) {
            return String(
                format: "%.0f",
                value
            )
        }

        return balance
    }

    private func percentage(
        _ value: Double
    ) -> Int {
        Int(value.rounded())
    }
}
