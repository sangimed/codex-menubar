import CodexMenuBarCore
import SwiftUI

struct LimitCard: View {
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

struct MetadataRow: View {
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
