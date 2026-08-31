import CodexMenuBarCore
import SwiftUI

struct AdditionalLimitsSection: View {
    let limits: [NamedRateLimit]

    @ObservedObject var preferences:
        PreferencesStore

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(
            "Additional Codex limits (\(limits.count))",
            isExpanded: $isExpanded
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
