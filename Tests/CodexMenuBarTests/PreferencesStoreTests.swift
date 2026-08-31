import XCTest
@testable import CodexMenuBar

@MainActor
final class PreferencesStoreTests:
    XCTestCase
{
    private let suiteName =
        "CodexMenuBar.PreferencesStoreTests"

    override func setUp() {
        super.setUp()
        UserDefaults.standard
            .removePersistentDomain(
                forName: suiteName
            )
    }

    override func tearDown() {
        UserDefaults.standard
            .removePersistentDomain(
                forName: suiteName
            )
        super.tearDown()
    }

    func testRefreshIntervalDefaultsToThirtySeconds()
    {
        let store = makeStore()

        XCTAssertEqual(
            store.refreshIntervalSeconds,
            30
        )
    }

    func testRefreshIntervalIsClampedToSafeRange()
    {
        let store = makeStore()

        store.setRefreshIntervalSeconds(1)
        XCTAssertEqual(
            store.refreshIntervalSeconds,
            PreferencesStore
                .minimumRefreshIntervalSeconds
        )

        store.setRefreshIntervalSeconds(999)
        XCTAssertEqual(
            store.refreshIntervalSeconds,
            PreferencesStore
                .maximumRefreshIntervalSeconds
        )
    }

    func testRefreshIntervalPersists()
    {
        let defaults = makeDefaults()

        let first =
            PreferencesStore(
                defaults: defaults
            )
        first.setRefreshIntervalSeconds(45)

        let second =
            PreferencesStore(
                defaults: defaults
            )

        XCTAssertEqual(
            second.refreshIntervalSeconds,
            45
        )
    }

    func testCreditsMenuBarPreferencePersists()
    {
        let defaults = makeDefaults()

        let first =
            PreferencesStore(
                defaults: defaults
            )
        first.showCreditsInMenuBar = true

        let second =
            PreferencesStore(
                defaults: defaults
            )

        XCTAssertTrue(
            second.showCreditsInMenuBar
        )
    }

    private func makeStore()
        -> PreferencesStore
    {
        PreferencesStore(
            defaults: makeDefaults()
        )
    }

    private func makeDefaults()
        -> UserDefaults
    {
        let defaults =
            UserDefaults(
                suiteName: suiteName
            )!

        defaults.removePersistentDomain(
            forName: suiteName
        )
        return defaults
    }
}
