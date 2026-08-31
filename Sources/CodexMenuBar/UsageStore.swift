import CodexMenuBarCore
import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set)
    var summary: CodexUsageSummary?

    @Published private(set)
    var isRefreshing = false

    @Published private(set)
    var errorMessage: String?

    @Published private(set)
    var lastUpdated: Date?

    @Published private(set)
    var history: [UsageHistoryEntry]

    let preferences: PreferencesStore

    var notificationsAvailable: Bool {
        notificationManager.isSupported
    }

    var notificationAvailabilityMessage: String? {
        notificationManager.isSupported
            ? nil
            : notificationManager.unsupportedReason
    }

    private let client: CodexAppServerClient
    private let notificationManager:
        UsageNotificationManager
    private let historyRepository:
        UsageHistoryRepository

    private var sessionTask:
        Task<Void, Never>?
    private var fallbackRefreshTask:
        Task<Void, Never>?
    private var refreshTimeoutTask:
        Task<Void, Never>?
    private var retryAttempt = 0

    private let retryDelays: [UInt64] = [
        1, 2, 5, 10, 30, 60
    ]

    private let fallbackRefreshIntervalNanoseconds:
        UInt64 = 30_000_000_000

    init(
        client:
            CodexAppServerClient =
            CodexAppServerClient(),
        preferences: PreferencesStore,
        notificationManager:
            UsageNotificationManager =
            UsageNotificationManager(),
        historyRepository:
            UsageHistoryRepository =
            UsageHistoryRepository()
    ) {
        self.client = client
        self.preferences = preferences
        self.notificationManager =
            notificationManager
        self.historyRepository =
            historyRepository
        self.history =
            historyRepository.load()
    }

    func start() {
        guard sessionTask == nil else {
            return
        }

        if preferences.notificationsEnabled {
            if notificationManager.isSupported {
                notificationManager
                    .requestAuthorization()
            } else {
                preferences.notificationsEnabled = false
            }
        }

        sessionTask = Task { [weak self] in
            await self?.runSessionLoop()
        }

        fallbackRefreshTask =
            Task { [weak self] in
                while !Task.isCancelled {
                    do {
                        try await Task.sleep(
                            nanoseconds:
                                fallbackRefreshIntervalNanoseconds
                        )
                    } catch {
                        return
                    }

                    guard let self else {
                        return
                    }

                    self.requestRefresh(
                        showActivity: false
                    )
                }
            }
    }

    func refresh() async {
        requestRefresh(
            showActivity: true
        )
    }

    func setNotificationsEnabled(
        _ enabled: Bool
    ) {
        guard enabled else {
            preferences.notificationsEnabled = false
            return
        }

        guard notificationManager.isSupported else {
            preferences.notificationsEnabled = false
            return
        }

        preferences.notificationsEnabled = true
        notificationManager
            .requestAuthorization()
    }

    func clearHistory() {
        history = []
        historyRepository.clear()
    }

    private func runSessionLoop() async {
        while !Task.isCancelled {
            do {
                try await client.runSession {
                    [weak self] incoming in

                    Task {
                        @MainActor [weak self] in
                        self?.apply(incoming)
                    }
                }

                if Task.isCancelled {
                    return
                }
            } catch {
                if Task.isCancelled {
                    return
                }

                errorMessage =
                    error.localizedDescription
                log(
                    error.localizedDescription
                )
                client.stop()

                let delay = retryDelays[
                    min(
                        retryAttempt,
                        retryDelays.count - 1
                    )
                ]

                retryAttempt = min(
                    retryAttempt + 1,
                    retryDelays.count - 1
                )

                log(
                    "Restarting app-server in \(delay)s"
                )

                do {
                    try await Task.sleep(
                        nanoseconds:
                            delay
                            * 1_000_000_000
                    )
                } catch {
                    return
                }
            }
        }
    }

    private func requestRefresh(
        showActivity: Bool
    ) {
        if showActivity {
            isRefreshing = true
            armRefreshTimeout()
        }

        do {
            try client.requestRefresh()
        } catch
            CodexAppServerError
                .notConnected
        {
            if showActivity {
                isRefreshing = false
                errorMessage =
                    CodexAppServerError
                    .notConnected
                    .localizedDescription
            }
        } catch {
            if showActivity {
                isRefreshing = false
                errorMessage =
                    error.localizedDescription
            }

            log(
                error.localizedDescription
            )
        }
    }

    private func apply(
        _ incoming: CodexUsageSummary
    ) {
        let previous = summary
        let merged =
            incoming.preservingMetadata(
                from: previous
            )

        if preferences
            .notificationsEnabled
        {
            notificationManager
                .notifyThresholdCrossings(
                    previous: previous,
                    current: merged,
                    threshold:
                        preferences
                        .notificationThreshold
                )
        }

        summary = merged
        history =
            historyRepository.appending(
                summary: merged,
                to: history
            )
        lastUpdated = Date()
        errorMessage = nil
        isRefreshing = false
        retryAttempt = 0

        refreshTimeoutTask?.cancel()
        refreshTimeoutTask = nil
    }

    private func armRefreshTimeout() {
        refreshTimeoutTask?.cancel()

        refreshTimeoutTask =
            Task { [weak self] in
                do {
                    try await Task.sleep(
                        nanoseconds:
                            10_000_000_000
                    )
                } catch {
                    return
                }

                guard let self else {
                    return
                }

                self.isRefreshing = false
            }
    }

    private func log(
        _ message: String
    ) {
        #if DEBUG
        let line =
            "[CodexMenuBar] \(message)\n"

        try? FileHandle.standardError
            .write(
                contentsOf:
                    Data(line.utf8)
            )
        #endif
    }

    deinit {
        sessionTask?.cancel()
        fallbackRefreshTask?.cancel()
        refreshTimeoutTask?.cancel()
        client.stop()
    }
}
