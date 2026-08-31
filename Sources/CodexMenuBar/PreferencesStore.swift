import CodexMenuBarCore
import Combine
import Foundation

enum PercentageMode: String, CaseIterable, Identifiable {
    case remaining
    case used

    var id: String { rawValue }

    var title: String {
        switch self {
        case .remaining: return "Remaining"
        case .used: return "Used"
        }
    }
}

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case both
    case fiveHour
    case weekly
    case iconOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .both: return "Both"
        case .fiveHour: return "5-hour"
        case .weekly: return "Weekly"
        case .iconOnly: return "Icon only"
        }
    }
}

@MainActor
final class PreferencesStore: ObservableObject {
    static let minimumRefreshIntervalSeconds = 15
    static let maximumRefreshIntervalSeconds = 300
    static let refreshIntervalStepSeconds = 5
    static let defaultRefreshIntervalSeconds = 30

    @Published var percentageMode: PercentageMode {
        didSet {
            defaults.set(
                percentageMode.rawValue,
                forKey: Keys.percentageMode
            )
        }
    }

    @Published var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            defaults.set(
                menuBarDisplayMode.rawValue,
                forKey: Keys.menuBarDisplayMode
            )
        }
    }

    @Published var showCreditsInMenuBar: Bool {
        didSet {
            defaults.set(
                showCreditsInMenuBar,
                forKey: Keys.showCreditsInMenuBar
            )
        }
    }

    @Published var notificationsEnabled: Bool {
        didSet {
            defaults.set(
                notificationsEnabled,
                forKey: Keys.notificationsEnabled
            )
        }
    }

    @Published var notificationThreshold: Int {
        didSet {
            defaults.set(
                notificationThreshold,
                forKey: Keys.notificationThreshold
            )
        }
    }

    @Published private(set)
    var refreshIntervalSeconds: Int

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        self.percentageMode = PercentageMode(
            rawValue: defaults.string(
                forKey: Keys.percentageMode
            ) ?? ""
        ) ?? .remaining

        self.menuBarDisplayMode = MenuBarDisplayMode(
            rawValue: defaults.string(
                forKey: Keys.menuBarDisplayMode
            ) ?? ""
        ) ?? .both

        self.showCreditsInMenuBar =
            defaults.object(
                forKey: Keys.showCreditsInMenuBar
            ) as? Bool ?? false

        self.notificationsEnabled =
            defaults.object(
                forKey: Keys.notificationsEnabled
            ) as? Bool ?? false

        let storedThreshold = defaults.integer(
            forKey: Keys.notificationThreshold
        )
        self.notificationThreshold =
            storedThreshold == 0 ? 20 : storedThreshold

        let storedRefreshInterval =
            defaults.object(
                forKey: Keys.refreshIntervalSeconds
            ) as? Int

        self.refreshIntervalSeconds =
            Self.clampedRefreshInterval(
                storedRefreshInterval
                    ?? Self.defaultRefreshIntervalSeconds
            )
    }

    func setRefreshIntervalSeconds(
        _ seconds: Int
    ) {
        let clamped =
            Self.clampedRefreshInterval(
                seconds
            )

        guard clamped != refreshIntervalSeconds
        else {
            return
        }

        refreshIntervalSeconds = clamped
        defaults.set(
            clamped,
            forKey: Keys.refreshIntervalSeconds
        )
    }

    func percentage(for window: RateLimitWindow) -> Double {
        switch percentageMode {
        case .remaining:
            return window.remainingPercent
        case .used:
            return window.usedPercent
        }
    }

    func secondaryPercentage(
        for window: RateLimitWindow
    ) -> Double {
        switch percentageMode {
        case .remaining:
            return window.usedPercent
        case .used:
            return window.remainingPercent
        }
    }

    var primaryLabel: String {
        percentageMode == .remaining
            ? "remaining"
            : "used"
    }

    var secondaryLabel: String {
        percentageMode == .remaining
            ? "used"
            : "remaining"
    }

    private static func clampedRefreshInterval(
        _ seconds: Int
    ) -> Int {
        max(
            minimumRefreshIntervalSeconds,
            min(
                maximumRefreshIntervalSeconds,
                seconds
            )
        )
    }

    private enum Keys {
        static let percentageMode = "percentageMode"
        static let menuBarDisplayMode = "menuBarDisplayMode"
        static let showCreditsInMenuBar = "showCreditsInMenuBar"
        static let notificationsEnabled = "notificationsEnabled"
        static let notificationThreshold = "notificationThreshold"
        static let refreshIntervalSeconds = "refreshIntervalSeconds"
    }
}
