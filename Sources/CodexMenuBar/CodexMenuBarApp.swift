import AppKit
import SwiftUI

@main
struct CodexMenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    @StateObject
    private var preferences: PreferencesStore

    @StateObject
    private var store: UsageStore

    @StateObject
    private var launchAtLogin =
        LaunchAtLoginManager()

    init() {
        let preferences =
            PreferencesStore()

        _preferences =
            StateObject(
                wrappedValue:
                    preferences
            )

        _store =
            StateObject(
                wrappedValue:
                    UsageStore(
                        preferences:
                            preferences
                    )
            )
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                store: store,
                preferences:
                    preferences,
                launchAtLogin:
                    launchAtLogin
            )
        } label: {
            MenuBarLabel(
                store: store,
                preferences:
                    preferences
            )
            .task {
                store.start()
                launchAtLogin
                    .refreshStatus()
            }
        }
        .menuBarExtraStyle(.window)
    }
}

private final class AppDelegate:
    NSObject,
    NSApplicationDelegate
{
    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        NSApp.setActivationPolicy(
            .accessory
        )
    }
}
