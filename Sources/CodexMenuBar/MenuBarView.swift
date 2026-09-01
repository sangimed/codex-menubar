import AppKit
import CodexMenuBarCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var preferences:
        PreferencesStore
    @ObservedObject var launchAtLogin:
        LaunchAtLoginManager

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
                        AdditionalLimitsSection(
                            limits:
                                summary
                                .additionalLimits,
                            preferences:
                                preferences
                        )
                    }

                    Divider()
                    metadata(summary)

                    UsageHistorySection(
                        store: store,
                        preferences: preferences
                    )
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

                PreferencesSection(
                    store: store,
                    preferences: preferences,
                    launchAtLogin:
                        launchAtLogin
                )

                Divider()
                footer
            }
            .padding(14)
        }
        .frame(width: 360)
        .frame(
            minHeight: 360,
            idealHeight: 460,
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

    private var footer: some View {
        HStack {
            if let lastUpdated =
                store.lastUpdated
            {
                HStack(spacing: 3) {
                    Text("Updated")
                    Text(
                        lastUpdated,
                        format:
                            .dateTime
                            .hour()
                            .minute()
                            .second()
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
}
