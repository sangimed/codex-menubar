import CodexMenuBarCore
import Foundation

struct UsageHistoryEntry:
    Codable,
    Identifiable,
    Equatable
{
    let id: UUID
    let timestamp: Date
    let fiveHourUsedPercent: Double?
    let weeklyUsedPercent: Double?
    let credits: String?

    init(
        summary: CodexUsageSummary,
        timestamp: Date = Date()
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.fiveHourUsedPercent =
            summary.fiveHour?.usedPercent
        self.weeklyUsedPercent =
            summary.weekly?.usedPercent
        self.credits = summary.credits?.balance
    }
}

final class UsageHistoryRepository {
    private let fileManager: FileManager
    private let fileURL: URL
    private let retentionInterval:
        TimeInterval = 7 * 24 * 60 * 60
    private let minimumSampleInterval:
        TimeInterval = 5 * 60

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let baseURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first
            ?? fileManager.homeDirectoryForCurrentUser

        let directory = baseURL.appendingPathComponent(
            "CodexMenuBar",
            isDirectory: true
        )

        try? fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        self.fileURL = directory.appendingPathComponent(
            "usage-history.json"
        )
    }

    func load() -> [UsageHistoryEntry] {
        guard let data = try? Data(
            contentsOf: fileURL
        ) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return (
            try? decoder.decode(
                [UsageHistoryEntry].self,
                from: data
            )
        ) ?? []
    }

    func appending(
        summary: CodexUsageSummary,
        to current: [UsageHistoryEntry],
        now: Date = Date()
    ) -> [UsageHistoryEntry] {
        let cutoff = now.addingTimeInterval(
            -retentionInterval
        )
        var entries = current.filter {
            $0.timestamp >= cutoff
        }
        let candidate = UsageHistoryEntry(
            summary: summary,
            timestamp: now
        )

        if let last = entries.last {
            let valuesChanged =
                last.fiveHourUsedPercent
                    != candidate.fiveHourUsedPercent
                || last.weeklyUsedPercent
                    != candidate.weeklyUsedPercent
                || last.credits != candidate.credits

            let intervalElapsed =
                now.timeIntervalSince(
                    last.timestamp
                ) >= minimumSampleInterval

            guard valuesChanged
                    || intervalElapsed else {
                return entries
            }
        }

        entries.append(candidate)

        if entries.count > 2_500 {
            entries.removeFirst(
                entries.count - 2_500
            )
        }

        save(entries)
        return entries
    }

    func clear() {
        try? fileManager.removeItem(
            at: fileURL
        )
    }

    private func save(
        _ entries: [UsageHistoryEntry]
    ) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [
            .prettyPrinted,
            .sortedKeys
        ]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(
            entries
        ) else {
            return
        }

        try? data.write(
            to: fileURL,
            options: .atomic
        )
    }
}
