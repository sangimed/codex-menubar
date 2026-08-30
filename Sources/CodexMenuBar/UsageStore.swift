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
    private var pollingTask: Task<Void, Never>?

    init(client: CodexAppServerClient = CodexAppServerClient()) {
        self.client = client
    }

    func start() {
        guard pollingTask == nil else {
            return
        }

        pollingTask = Task { [weak self] in
            guard let self else {
                return
            }

            await self.refresh()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                } catch {
                    return
                }

                await self.refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            summary = try await client.fetchUsage()
            lastUpdated = Date()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    deinit {
        pollingTask?.cancel()
    }
}
