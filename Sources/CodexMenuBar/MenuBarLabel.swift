import CodexMenuBarCore
import SwiftUI

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.with.dots.needle.67percent")

            if let summary = store.summary {
                if let fiveHour = summary.fiveHour {
                    Text("\(percentage(fiveHour.usedPercent))%")
                }

                if let weekly = summary.weekly {
                    Text("W\(percentage(weekly.usedPercent))%")
                }
            } else {
                Text("Codex")
            }
        }
        .help(store.errorMessage ?? "Codex usage")
    }

    private func percentage(_ value: Double) -> Int {
        Int(value.rounded())
    }
}
