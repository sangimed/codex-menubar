import Combine
import ServiceManagement

@MainActor
final class LaunchAtLoginManager:
    ObservableObject
{
    @Published private(set)
    var isEnabled: Bool

    @Published private(set)
    var errorMessage: String?

    init() {
        isEnabled =
            SMAppService.mainApp.status
            == .enabled
    }

    func refreshStatus() {
        isEnabled =
            SMAppService.mainApp.status
            == .enabled
    }

    func setEnabled(
        _ enabled: Bool
    ) async {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try await
                    SMAppService.mainApp
                    .unregister()
            }

            errorMessage = nil
            refreshStatus()
        } catch {
            errorMessage =
                error.localizedDescription
            refreshStatus()
        }
    }
}
