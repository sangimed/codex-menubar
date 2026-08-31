import SwiftUI

struct UsageHistorySection: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var preferences:
        PreferencesStore

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(
            "Usage history (\(store.history.count))",
            isExpanded: $isExpanded
        ) {
            VStack(spacing: 6) {
                ForEach(
                    store.history
                        .suffix(10)
                        .reversed()
                ) { entry in
                    HStack {
                        Text(
                            entry.timestamp,
                            style: .time
                        )
                        .foregroundStyle(
                            .secondary
                        )

                        Spacer()

                        if let five =
                            entry
                            .fiveHourUsedPercent
                        {
                            Text(
                                "5h \(historyPercentage(used: five))%"
                            )
                        }

                        if let weekly =
                            entry
                            .weeklyUsedPercent
                        {
                            Text(
                                "W \(historyPercentage(used: weekly))%"
                            )
                        }
                    }
                    .font(
                        .caption
                        .monospacedDigit()
                    )
                }

                if store.history.isEmpty {
                    Text(
                        "History will appear as usage updates arrive."
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                } else {
                    HStack {
                        Text(
                            "Stored locally for 7 days"
                        )
                        .font(.caption2)
                        .foregroundStyle(
                            .secondary
                        )

                        Spacer()

                        Button("Clear") {
                            store.clearHistory()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            .padding(.top, 6)
        }
        .font(.caption)
    }

    private func historyPercentage(
        used: Double
    ) -> Int {
        switch preferences
            .percentageMode
        {
        case .used:
            return Int(
                used.rounded()
            )

        case .remaining:
            return Int(
                max(
                    0,
                    min(
                        100,
                        100 - used
                    )
                ).rounded()
            )
        }
    }
}
