import CodexMenuBarCore
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

        switch preferences
            .menuBarDisplayMode
        {
        case .both:
            return [fiveHour, weekly]
                .compactMap { $0 }
                .joined(separator: " · ")

        case .fiveHour:
            return fiveHour ?? "—"

        case .weekly:
            return weekly ?? "W—"

        case .iconOnly:
            return ""
        }
    }

    private func percentage(
        _ value: Double
    ) -> Int {
        Int(value.rounded())
    }
}
