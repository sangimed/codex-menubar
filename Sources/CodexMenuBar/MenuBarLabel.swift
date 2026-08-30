import CodexMenuBarCore
import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.with.dots.needle.67percent")
            Text(menuBarText)
                .monospacedDigit()
        }
        .help(store.errorMessage ?? "Codex usage")
    }

    private var menuBarText: String {
        guard let summary = store.summary else {
            return "Codex"
        }

        switch (summary.fiveHour, summary.weekly) {
        case let (fiveHour?, weekly?):
            return "\(percentage(fiveHour.usedPercent))% · W\(percentage(weekly.usedPercent))%"

        case let (fiveHour?, nil):
            return "\(percentage(fiveHour.usedPercent))%"

        case let (nil, weekly?):
            return "W\(percentage(weekly.usedPercent))%"

        case (nil, nil):
            return "Codex"
        }
    }

    private func percentage(_ value: Double) -> Int {
        Int(value.rounded())
    }
}
