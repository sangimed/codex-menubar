import Foundation

public struct RateLimitWindow: Codable, Equatable, Sendable {
    public let usedPercent: Double
    public let windowDurationMins: Int
    public let resetsAt: Int64

    public init(usedPercent: Double, windowDurationMins: Int, resetsAt: Int64) {
        self.usedPercent = usedPercent
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
    }

    public var remainingPercent: Double {
        max(0, min(100, 100 - usedPercent))
    }

    public var resetDate: Date {
        Date(timeIntervalSince1970: TimeInterval(resetsAt))
    }
}

public struct CodexCredits: Codable, Equatable, Sendable {
    public let hasCredits: Bool
    public let unlimited: Bool
    public let balance: String?

    public init(hasCredits: Bool, unlimited: Bool, balance: String?) {
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.balance = balance
    }
}

public struct RateLimitSnapshot: Codable, Equatable, Sendable {
    public let limitId: String?
    public let primary: RateLimitWindow?
    public let secondary: RateLimitWindow?
    public let credits: CodexCredits?
    public let planType: String?

    public init(
        limitId: String?,
        primary: RateLimitWindow?,
        secondary: RateLimitWindow?,
        credits: CodexCredits?,
        planType: String?
    ) {
        self.limitId = limitId
        self.primary = primary
        self.secondary = secondary
        self.credits = credits
        self.planType = planType
    }
}

public struct RateLimitsResponse: Codable, Equatable, Sendable {
    public let rateLimits: RateLimitSnapshot
    public let rateLimitsByLimitId: [String: RateLimitSnapshot]?

    public init(
        rateLimits: RateLimitSnapshot,
        rateLimitsByLimitId: [String: RateLimitSnapshot]?
    ) {
        self.rateLimits = rateLimits
        self.rateLimitsByLimitId = rateLimitsByLimitId
    }
}

public struct CodexUsageSummary: Equatable, Sendable {
    public static let fiveHourWindowMinutes = 300
    public static let weeklyWindowMinutes = 10_080

    public let fiveHour: RateLimitWindow?
    public let weekly: RateLimitWindow?
    public let credits: CodexCredits?
    public let planType: String?

    public init(response: RateLimitsResponse) {
        let snapshot = response.rateLimitsByLimitId?["codex"] ?? response.rateLimits
        let windows = [snapshot.primary, snapshot.secondary].compactMap { $0 }

        self.fiveHour = windows.first {
            $0.windowDurationMins == Self.fiveHourWindowMinutes
        }
        self.weekly = windows.first {
            $0.windowDurationMins == Self.weeklyWindowMinutes
        }
        self.credits = snapshot.credits
        self.planType = snapshot.planType
    }
}
