import AppKit
import CodexMenuBarCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var preferences:
        PreferencesStore
    @ObservedObject var launchAtLogin:
        LaunchAtLoginManager

    @State private var showPreferences = false
    @State private var showHistory = false
    @State private var showAdditionalLimits = false

    var body: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                header

                if let summary = store.summary {
                    LimitCard(
                        title: "5-hour window",
                        window: summary.fiveHour,
                        preferences: preferences
                    )

                    LimitCard(
                        title: "Weekly",
                        window: summary.weekly,
                        preferences: preferences
                    )

                    if !summary
                        .additionalLimits
                        .isEmpty
                    {
                        additionalLimits(
                            summary
                                .additionalLimits
                        )
                    }

                    Divider()
                    metadata(summary)
                    historySection
                } else if store.isRefreshing {
                    loadingState
                } else {
                    Text(
                        "No Codex usage data yet."
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 80
                    )
                }

                if let errorMessage =
                    store.errorMessage
                {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(
                            .secondary
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }

                preferencesSection

                Divider()
                footer
            }
            .padding(14)
        }
        .frame(
            width: 360,
            maxHeight: 650
        )
    }

    private var header: some View {
        HStack {
            VStack(
                alignment: .leading,
                spacing: 2
            ) {
                Text("CodexMenuBar")
                    .font(.headline)

                Text(
                    "Codex usage at a glance"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Button {
                Task {
                    await store.refresh()
                }
            } label: {
                Image(
                    systemName:
                        "arrow.clockwise"
                )
            }
            .buttonStyle(.borderless)
            .disabled(
                store.isRefreshing
            )
            .help("Refresh")
        }
    }

    private var loadingState:
        some View
    {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)

            Text(
                "Loading Codex usage…"
            )
            .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 80
        )
    }

    @ViewBuilder
    private func metadata(
        _ summary: CodexUsageSummary
    ) -> some View {
        VStack(spacing: 6) {
            MetadataRow(
                label: "Plan",
                value:
                    summary
                    .planType?
                    .capitalized
                    ?? "—"
            )

            if let credits =
                summary.credits,
               credits.hasCredits
            {
                MetadataRow(
                    label: "Credits",
                    value:
                        creditsText(
                            credits
                        )
                )
            }
        }
    }

    private var preferencesSection:
        some View
    {
        DisclosureGroup(
            "Preferences",
            isExpanded:
                $showPreferences
        ) {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                Picker(
                    "Percentage",
                    selection:
                        $preferences
                        .percentageMode
                ) {
                    ForEach(
                        PercentageMode
                            .allCases
                    ) { mode in
                        Text(mode.title)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker(
                    "Menu bar",
                    selection:
                        $preferences
                        .menuBarDisplayMode
                ) {
                    ForEach(
                        MenuBarDisplayMode
                            .allCases
                    ) { mode in
                        Text(mode.title)
                            .tag(mode)
                    }
                }

                Toggle(
                    "Quota threshold notifications",
                    isOn: Binding(
                        get: {
                            preferences
                                .notificationsEnabled
                        },
                        set: {
                            store
                                .setNotificationsEnabled(
                                    $0
                                )
                        }
                    )
                )

                if preferences
                    .notificationsEnabled
                {
                    Stepper(
                        "Notify at \(preferences.notificationThreshold)% remaining",
                        value:
                            $preferences
                            .notificationThreshold,
                        in: 5...50,
                        step: 5
                    )
                }

                Toggle(
                    "Launch at login",
                    isOn: Binding(
                        get: {
                            launchAtLogin
                                .isEnabled
                        },
                        set: {
                            enabled in

                            Task {
                                await
                                    launchAtLogin
                                    .setEnabled(
                                        enabled
                                    )
                            }
                        }
                    )
                )

                if let error =
                    launchAtLogin
                    .errorMessage
                {
                    Text(error)
                        .font(
                            .caption2
                        )
                        .foregroundStyle(
                            .secondary
                        )
                        .fixedSize(
                            horizontal:
                                false,
                            vertical:
                                true
                        )
                }
            }
            .padding(.top, 8)
        }
        .font(.caption)
    }

    private var historySection:
        some View
    {
        DisclosureGroup(
            "Usage history (\(store.history.count))",
            isExpanded: $showHistory
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
                            store
                                .clearHistory()
                        }
                        .buttonStyle(
                            .borderless
                        )
                    }
                }
            }
            .padding(.top, 6)
        }
        .font(.caption)
    }

    private func additionalLimits(
        _ limits: [NamedRateLimit]
    ) -> some View {
        DisclosureGroup(
            "Additional Codex limits (\(limits.count))",
            isExpanded:
                $showAdditionalLimits
        ) {
            VStack(
                alignment: .leading,
                spacing: 10
            ) {
                ForEach(limits) {
                    limit in

                    VStack(
                        alignment: .leading,
                        spacing: 5
                    ) {
                        Text(limit.name)
                            .font(
                                .caption
                                .weight(
                                    .semibold
                                )
                            )

                        ForEach(
                            Array(
                                limit
                                    .windows
                                    .enumerated()
                            ),
                            id: \.offset
                        ) {
                            _,
                            window in

                            HStack {
                                Text(
                                    windowTitle(
                                        window
                                    )
                                )
                                .foregroundStyle(
                                    .secondary
                                )

                                Spacer()

                                Text(
                                    "\(Int(preferences.percentage(for: window).rounded()))% \(preferences.primaryLabel)"
                                )
                                .monospacedDigit()
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .padding(.top, 6)
        }
        .font(.caption)
    }

    private var footer: some View {
        HStack {
            if let lastUpdated =
                store.lastUpdated
            {
                HStack(spacing: 3) {
                    Text("Updated")
                    Text(
                        lastUpdated,
                        style: .relative
                    )
                }
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            } else {
                Text(
                    "Not updated yet"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }

            Spacer()

            Button("Quit") {
                NSApplication.shared
                    .terminate(nil)
            }
            .buttonStyle(.borderless)
        }
    }

    private func creditsText(
        _ credits: CodexCredits
    ) -> String {
        if credits.unlimited {
            return "Unlimited"
        }

        guard let balance =
            credits.balance
        else {
            return "—"
        }

        if let value =
            Double(balance)
        {
            return String(
                format: "%.0f",
                value
            )
        }

        return balance
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

    private func windowTitle(
        _ window: RateLimitWindow
    ) -> String {
        switch window
            .windowDurationMins
        {
        case 300:
            return "5-hour"

        case 10_080:
            return "Weekly"

        case let minutes
            where minutes % 1_440 == 0:
            return
                "\(minutes / 1_440)d window"

        case let minutes
            where minutes % 60 == 0:
            return
                "\(minutes / 60)h window"

        default:
            return
                "\(window.windowDurationMins)m window"
        }
    }
}

private struct LimitCard: View {
    let title: String
    let window: RateLimitWindow?

    @ObservedObject
    var preferences: PreferencesStore

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 7
        ) {
            HStack {
                Text(title)
                    .font(
                        .subheadline
                        .weight(
                            .semibold
                        )
                    )

                Spacer()

                if let window {
                    Text(
                        "\(Int(preferences.percentage(for: window).rounded()))% \(preferences.primaryLabel)"
                    )
                    .font(
                        .subheadline
                        .monospacedDigit()
                    )
                }
            }

            if let window {
                ProgressView(
                    value: max(
                        0,
                        min(
                            100,
                            preferences
                                .percentage(
                                    for:
                                        window
                                )
                        )
                    ),
                    total: 100
                )

                HStack {
                    Text(
                        "\(Int(preferences.secondaryPercentage(for: window).rounded()))% \(preferences.secondaryLabel)"
                    )
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )

                    Spacer()

                    HStack(spacing: 3) {
                        Text("Resets")
                        Text(
                            window.resetDate,
                            style: .relative
                        )
                    }
                    .font(.caption)
                    .foregroundStyle(
                        .secondary
                    )
                }
            } else {
                Text(
                    "Not currently reported by Codex"
                )
                .font(.caption)
                .foregroundStyle(
                    .secondary
                )
            }
        }
        .padding(10)
        .background(
            .quaternary
            .opacity(0.35)
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: 10,
                style: .continuous
            )
        )
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(
                    .secondary
                )

            Spacer()

            Text(value)
                .monospacedDigit()
        }
        .font(.caption)
    }
}
