import CodexMenuBarCore
import Combine
import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var summary: CodexUsageSummary?
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    private let client: CodexAppServerClient
    private var sessionTask: Task<Void, Never>?
    private var fallbackRefreshTask: Task<Void, Never>?
    private var refreshTimeoutTask: Task<Void, Never>?
    private var retryAttempt = 0

    private let retryDelays: [UInt64] = [1, 2, 5, 10, 30, 60]

    init(client: CodexAppServerClient = CodexAppServerClient()) {
        self.client = client
    }

    func start() {
        guard sessionTask == nil else {
            return
        }

        sessionTask = Task { [weak self] in
            await self?.runSessionLoop()
        }

        fallbackRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(
                        nanoseconds: 300_000_000_000
                    )
                } catch {
                    return
                }

                guard let self else {
                    return
                }

                self.requestRefresh(showActivity: false)
            }
        }
    }

    func refresh() async {
        requestRefresh(showActivity: true)
    }

    private func runSessionLoop() async {
        while !Task.isCancelled {
            do {
                try await client.runSession { [weak self] incoming in
                    Task { @MainActor [weak self] in
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

                errorMessage = error.localizedDescription
                log(error.localizedDescription)
                client.stop()

                let delay = retryDelays[
                    min(retryAttempt, retryDelays.count - 1)
                ]
                retryAttempt = min(
                    retryAttempt + 1,
                    retryDelays.count - 1
                )

                log("Restarting app-server in \(delay)s")

                do {
                    try await Task.sleep(
                        nanoseconds: delay * 1_000_000_000
                    )
                } catch {
                    return
                }
            }
        }
    }

    private func requestRefresh(showActivity: Bool) {
        if showActivity {
            isRefreshing = true
            armRefreshTimeout()
        }

        do {
            try client.requestRefresh()
        } catch CodexAppServerError.notConnected {
            if showActivity {
                isRefreshing = false
            }

            // The session loop owns connection/reconnection state. A fallback
            // refresh can race with startup, so don't surface that as a user
            // error unless the user explicitly requested the refresh.
            if showActivity {
                errorMessage = CodexAppServerError.notConnected.localizedDescription
            }
        } catch {
            if showActivity {
                isRefreshing = false
                errorMessage = error.localizedDescription
            }

            log(error.localizedDescription)
        }
    }

    private func apply(_ incoming: CodexUsageSummary) {
        summary = incoming.preservingMetadata(from: summary)
        lastUpdated = Date()
        errorMessage = nil
        isRefreshing = false
        retryAttempt = 0
        refreshTimeoutTask?.cancel()
        refreshTimeoutTask = nil
    }

    private func armRefreshTimeout() {
        refreshTimeoutTask?.cancel()

        refreshTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(
                    nanoseconds: 10_000_000_000
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

    private func log(_ message: String) {
        #if DEBUG
        let line = "[CodexMenuBar] \(message)\n"
        try? FileHandle.standardError.write(
            contentsOf: Data(line.utf8)
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
