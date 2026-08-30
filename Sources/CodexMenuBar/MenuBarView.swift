import AppKit
import CodexMenuBarCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let summary = store.summary {
                LimitCard(
                    title: "5-hour window",
                    window: summary.fiveHour
                )

                LimitCard(
                    title: "Weekly",
                    window: summary.weekly
                )

                Divider()

                metadata(summary)
            } else if store.isRefreshing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading Codex usage…")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                Text("No Codex usage data yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            }

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            footer
        }
        .padding(14)
        .frame(width: 330)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("CodexMenuBar")
                    .font(.headline)

                Text("Codex usage at a glance")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                Task {
                    await store.refresh()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(store.isRefreshing)
            .help("Refresh")
        }
    }

    @ViewBuilder
    private func metadata(_ summary: CodexUsageSummary) -> some View {
        VStack(spacing: 6) {
            MetadataRow(
                label: "Plan",
                value: summary.planType?.capitalized ?? "—"
            )

            if let credits = summary.credits, credits.hasCredits {
                MetadataRow(
                    label: "Credits",
                    value: creditsText(credits)
                )
            }
        }
    }

    private var footer: some View {
        HStack {
            if let lastUpdated = store.lastUpdated {
                HStack(spacing: 3) {
                    Text("Updated")
                    Text(lastUpdated, style: .relative)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else {
                Text("Not updated yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
    }

    private func creditsText(_ credits: CodexCredits) -> String {
        if credits.unlimited {
            return "Unlimited"
        }

        guard let balance = credits.balance else {
            return "—"
        }

        if let value = Double(balance) {
            return String(format: "%.0f", value)
        }

        return balance
    }
}

private struct LimitCard: View {
    let title: String
    let window: RateLimitWindow?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if let window {
                    Text("\(Int(window.usedPercent.rounded()))% used")
                        .font(.subheadline.monospacedDigit())
                }
            }

            if let window {
                ProgressView(
                    value: max(0, min(100, window.remainingPercent)),
                    total: 100
                )

                HStack {
                    Text("\(Int(window.remainingPercent.rounded()))% remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 3) {
                        Text("Resets")
                        Text(window.resetDate, style: .relative)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } else {
                Text("Not currently reported by Codex")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .monospacedDigit()
        }
        .font(.caption)
    }
}
