import Foundation

public enum CodexAppServerError:
    LocalizedError,
    Equatable
{
    case codexNotFound
    case sessionAlreadyRunning
    case notConnected
    case timedOut(stage: String)
    case unexpectedEndOfOutput
    case malformedResponse
    case transportWriteFailed(
        stage: String,
        message: String
    )
    case transportReadFailed(
        stage: String,
        message: String
    )
    case rpcError(
        code: Int?,
        message: String
    )

    public var errorDescription: String? {
        switch self {
        case .codexNotFound:
            return "Codex CLI was not found. Install Codex or set CODEX_EXECUTABLE to its full path."

        case .sessionAlreadyRunning:
            return "A Codex app-server session is already running."

        case .notConnected:
            return "Codex app-server is not connected yet."

        case let .timedOut(stage):
            return "Codex app-server timed out while waiting for \(stage)."

        case .unexpectedEndOfOutput:
            return "Codex app-server stopped unexpectedly."

        case .malformedResponse:
            return "Codex app-server returned a response that CodexMenuBar could not understand."

        case let .transportWriteFailed(
            stage,
            message
        ):
            return "Could not send \(stage) to Codex app-server: \(message)"

        case let .transportReadFailed(
            stage,
            message
        ):
            return "Could not read \(stage) from Codex app-server: \(message)"

        case let .rpcError(
            code,
            message
        ):
            if let code {
                return "Codex app-server error \(code): \(message)"
            }

            return "Codex app-server error: \(message)"
        }
    }
}
