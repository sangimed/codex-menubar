import SwiftUI

struct PreferencesSection: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var preferences:
        PreferencesStore
    @ObservedObject var launchAtLogin:
        LaunchAtLoginManager

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(
            "Preferences",
            isExpanded: $isExpanded
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
                    "Show credits in menu bar",
                    isOn:
                        $preferences
                        .showCreditsInMenuBar
                )
                .help(
                    "Show the available Codex credit balance in the menu bar when Codex reports it."
                )

                Stepper(
                    "Refresh every \(preferences.refreshIntervalSeconds) seconds",
                    value: Binding(
                        get: {
                            preferences
                                .refreshIntervalSeconds
                        },
                        set: {
                            store
                                .setRefreshIntervalSeconds(
                                    $0
                                )
                        }
                    ),
                    in:
                        PreferencesStore
                        .minimumRefreshIntervalSeconds
                        ...
                        PreferencesStore
                        .maximumRefreshIntervalSeconds,
                    step:
                        PreferencesStore
                        .refreshIntervalStepSeconds
                )
                .help(
                    "How often CodexMenuBar polls Codex for fresh usage data. Push updates are still applied immediately."
                )

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
                .disabled(
                    !store.notificationsAvailable
                )

                if let message =
                    store.notificationAvailabilityMessage
                {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(
                            .secondary
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }

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
                        .font(.caption2)
                        .foregroundStyle(
                            .secondary
                        )
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
            }
            .padding(.top, 8)
        }
        .font(.caption)
    }
}
