import XCTest
@testable import CodexMenuBarCore

final class RateLimitModelsTests: XCTestCase {
    func testDecodesFiveHourWeeklyAndCredits() throws {
        let data = Data(
            """
            {
              "rateLimits": {
                "limitId": "codex",
                "primary": {
                  "usedPercent": 82,
                  "windowDurationMins": 300,
                  "resetsAt": 1788125155
                },
                "secondary": {
                  "usedPercent": 26,
                  "windowDurationMins": 10080,
                  "resetsAt": 1788693894
                },
                "credits": {
                  "hasCredits": true,
                  "unlimited": false,
                  "balance": "616.2757055000"
                },
                "planType": "plus"
              },
              "rateLimitsByLimitId": {
                "codex": {
                  "limitId": "codex",
                  "primary": {
                    "usedPercent": 82,
                    "windowDurationMins": 300,
                    "resetsAt": 1788125155
                  },
                  "secondary": {
                    "usedPercent": 26,
                    "windowDurationMins": 10080,
                    "resetsAt": 1788693894
                  },
                  "credits": {
                    "hasCredits": true,
                    "unlimited": false,
                    "balance": "616.2757055000"
                  },
                  "planType": "plus"
                }
              }
            }
            """.utf8
        )

        let response = try JSONDecoder().decode(
            RateLimitsResponse.self,
            from: data
        )
        let summary = CodexUsageSummary(response: response)

        XCTAssertEqual(summary.fiveHour?.usedPercent, 82)
        XCTAssertEqual(summary.weekly?.usedPercent, 26)
        XCTAssertEqual(summary.credits?.balance, "616.2757055000")
        XCTAssertEqual(summary.planType, "plus")
    }

    func testClassifiesWindowsByDurationNotPrimarySecondaryPosition() {
        let weekly = RateLimitWindow(
            usedPercent: 10,
            windowDurationMins: 10_080,
            resetsAt: 100
        )
        let fiveHour = RateLimitWindow(
            usedPercent: 20,
            windowDurationMins: 300,
            resetsAt: 200
        )

        let snapshot = RateLimitSnapshot(
            limitId: "codex",
            primary: weekly,
            secondary: fiveHour,
            credits: nil,
            planType: "plus"
        )

        let summary = CodexUsageSummary(
            response: RateLimitsResponse(
                rateLimits: snapshot,
                rateLimitsByLimitId: nil
            )
        )

        XCTAssertEqual(summary.fiveHour, fiveHour)
        XCTAssertEqual(summary.weekly, weekly)
    }

    func testPrefersCodexNamedBucket() {
        let fallbackWindow = RateLimitWindow(
            usedPercent: 99,
            windowDurationMins: 300,
            resetsAt: 100
        )
        let codexWindow = RateLimitWindow(
            usedPercent: 42,
            windowDurationMins: 300,
            resetsAt: 200
        )

        let fallback = RateLimitSnapshot(
            limitId: "other",
            primary: fallbackWindow,
            secondary: nil,
            credits: nil,
            planType: nil
        )
        let codex = RateLimitSnapshot(
            limitId: "codex",
            primary: codexWindow,
            secondary: nil,
            credits: nil,
            planType: "plus"
        )

        let summary = CodexUsageSummary(
            response: RateLimitsResponse(
                rateLimits: fallback,
                rateLimitsByLimitId: ["codex": codex]
            )
        )

        XCTAssertEqual(summary.fiveHour?.usedPercent, 42)
        XCTAssertEqual(summary.planType, "plus")
    }

    func testRemainingPercentageIsClamped() {
        XCTAssertEqual(
            RateLimitWindow(
                usedPercent: 82,
                windowDurationMins: 300,
                resetsAt: 0
            ).remainingPercent,
            18
        )

        XCTAssertEqual(
            RateLimitWindow(
                usedPercent: 120,
                windowDurationMins: 300,
                resetsAt: 0
            ).remainingPercent,
            0
        )
    }
    func testPreservesMissingNotificationMetadata() {
        let previous = CodexUsageSummary(
            fiveHour: RateLimitWindow(
                usedPercent: 80,
                windowDurationMins: 300,
                resetsAt: 100
            ),
            weekly: RateLimitWindow(
                usedPercent: 20,
                windowDurationMins: 10_080,
                resetsAt: 200
            ),
            credits: CodexCredits(
                hasCredits: true,
                unlimited: false,
                balance: "616"
            ),
            planType: "plus"
        )

        let notification = CodexUsageSummary(
            fiveHour: RateLimitWindow(
                usedPercent: 81,
                windowDurationMins: 300,
                resetsAt: 100
            ),
            weekly: RateLimitWindow(
                usedPercent: 21,
                windowDurationMins: 10_080,
                resetsAt: 200
            ),
            credits: nil,
            planType: nil
        )

        let merged = notification.preservingMetadata(from: previous)

        XCTAssertEqual(merged.fiveHour?.usedPercent, 81)
        XCTAssertEqual(merged.weekly?.usedPercent, 21)
        XCTAssertEqual(merged.credits?.balance, "616")
        XCTAssertEqual(merged.planType, "plus")
    }
}
