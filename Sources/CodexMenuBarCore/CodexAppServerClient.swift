import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum CodexAppServerError: LocalizedError, Equatable {
    case codexNotFound
    case timedOut(stage: String)
    case unexpectedEndOfOutput
    case malformedResponse
    case transportWriteFailed(stage: String, message: String)
    case rpcError(code: Int?, message: String)

    public var errorDescription: String? {
        switch self {
        case .codexNotFound:
            return "Codex CLI was not found. Install Codex or set CODEX_EXECUTABLE to its full path."
        case let .timedOut(stage):
            return "Codex app-server timed out while waiting for \(stage)."
        case .unexpectedEndOfOutput:
            return "Codex app-server stopped before returning the usage limits."
        case .malformedResponse:
            return "Codex app-server returned a response that CodexMenuBar could not understand."
        case let .transportWriteFailed(stage, message):
            return "Could not send \(stage) to Codex app-server: \(message)"
        case let .rpcError(code, message):
            if let code {
                return "Codex app-server error \(code): \(message)"
            }
            return "Codex app-server error: \(message)"
        }
    }
}

public final class CodexAppServerClient: @unchecked Sendable {
    private let initializeTimeout: TimeInterval
    private let requestTimeout: TimeInterval

    public init(
        initializeTimeout: TimeInterval = 60,
        requestTimeout: TimeInterval = 60
    ) {
        self.initializeTimeout = initializeTimeout
        self.requestTimeout = requestTimeout

        #if canImport(Darwin)
        // A child process may close stdin before a JSON-RPC write completes.
        // Ignore SIGPIPE so a closed pipe becomes a normal Swift error.
        signal(SIGPIPE, SIG_IGN)
        #endif
    }

    public func fetchUsage() async throws -> CodexUsageSummary {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try self.fetchUsageSynchronously())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchUsageSynchronously() throws -> CodexUsageSummary {
        let executable = try resolveCodexExecutable()

        #if DEBUG
        debugLog("Using Codex executable: \(executable)")
        #endif

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.standardError

        do {
            try process.run()
        } catch {
            throw CodexAppServerError.codexNotFound
        }

        defer {
            try? inputPipe.fileHandleForWriting.close()
            if process.isRunning {
                process.terminate()
            }
        }

        let reader = JSONLineReader(handle: outputPipe.fileHandleForReading)

        try send(
            [
                "method": "initialize",
                "id": 1,
                "params": [
                    "clientInfo": [
                        "name": "codex-menubar",
                        "title": "CodexMenuBar",
                        "version": "0.1.0"
                    ],
                    "capabilities": [
                        "experimentalApi": false
                    ]
                ]
            ],
            stage: "initialize",
            to: inputPipe.fileHandleForWriting
        )

        #if DEBUG
        debugLog("Waiting for app-server initialization…")
        #endif

        let initializeResponse = try readResponse(
            id: 1,
            from: reader,
            timeout: initializeTimeout,
            stage: "app-server initialization"
        )
        try throwIfRPCError(in: initializeResponse)

        #if DEBUG
        debugLog("App-server initialized")
        #endif

        try send(
            ["method": "initialized"],
            stage: "initialized notification",
            to: inputPipe.fileHandleForWriting
        )

        #if DEBUG
        debugLog("Sent initialized notification")
        #endif

        try send(
            [
                "method": "account/rateLimits/read",
                "id": 2
            ],
            stage: "account/rateLimits/read",
            to: inputPipe.fileHandleForWriting
        )

        #if DEBUG
        debugLog("Waiting for account/rateLimits/read…")
        #endif

        let rateLimitsData = try readResponse(
            id: 2,
            from: reader,
            timeout: requestTimeout,
            stage: "account/rateLimits/read"
        )

        let response = try JSONDecoder().decode(
            RPCResponse<RateLimitsResponse>.self,
            from: rateLimitsData
        )

        if let error = response.error {
            throw CodexAppServerError.rpcError(
                code: error.code,
                message: error.message
            )
        }

        guard let result = response.result else {
            throw CodexAppServerError.malformedResponse
        }

        #if DEBUG
        debugLog("Received Codex rate limits")
        #endif

        return CodexUsageSummary(response: result)
    }

    private func resolveCodexExecutable() throws -> String {
        let environment = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default

        if let override = environment["CODEX_EXECUTABLE"],
           fileManager.isExecutableFile(atPath: override) {
            return override
        }

        var candidates: [String] = []

        if let path = environment["PATH"] {
            candidates.append(
                contentsOf: path
                    .split(separator: ":")
                    .map { "\($0)/codex" }
            )
        }

        let home = fileManager.homeDirectoryForCurrentUser.path
        candidates.append(contentsOf: [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(home)/.local/bin/codex",
            "\(home)/.npm-global/bin/codex",
            "\(home)/.volta/bin/codex",
            "\(home)/.asdf/shims/codex",
            "\(home)/.local/share/mise/shims/codex"
        ])

        let nvmVersions = "\(home)/.nvm/versions/node"
        if let versions = try? fileManager.contentsOfDirectory(atPath: nvmVersions) {
            candidates.append(
                contentsOf: versions
                    .sorted(by: >)
                    .map { "\(nvmVersions)/\($0)/bin/codex" }
            )
        }

        if let executable = candidates.first(where: {
            fileManager.isExecutableFile(atPath: $0)
        }) {
            return executable
        }

        throw CodexAppServerError.codexNotFound
    }

    private func send(
        _ object: [String: Any],
        stage: String,
        to handle: FileHandle
    ) throws {
        do {
            var data = try JSONSerialization.data(withJSONObject: object)
            data.append(0x0A)
            try handle.write(contentsOf: data)
        } catch {
            throw CodexAppServerError.transportWriteFailed(
                stage: stage,
                message: detailedErrorDescription(error)
            )
        }
    }

    private func readResponse(
        id expectedId: Int,
        from reader: JSONLineReader,
        timeout: TimeInterval,
        stage: String
    ) throws -> Data {
        let deadline = DispatchTime.now().uptimeNanoseconds
            + UInt64(timeout * 1_000_000_000)

        while true {
            guard let line = try reader.readLine(deadlineNanoseconds: deadline) else {
                throw CodexAppServerError.unexpectedEndOfOutput
            }

            guard !line.isEmpty else {
                continue
            }

            guard
                let object = try JSONSerialization.jsonObject(with: line) as? [String: Any]
            else {
                throw CodexAppServerError.malformedResponse
            }

            if let id = object["id"] as? NSNumber,
               id.intValue == expectedId {
                return line
            }

            if DispatchTime.now().uptimeNanoseconds >= deadline {
                throw CodexAppServerError.timedOut(stage: stage)
            }
        }
    }

    private func throwIfRPCError(in data: Data) throws {
        guard
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw CodexAppServerError.malformedResponse
        }

        guard let error = object["error"] as? [String: Any] else {
            return
        }

        throw CodexAppServerError.rpcError(
            code: (error["code"] as? NSNumber)?.intValue,
            message: error["message"] as? String ?? "Unknown error"
        )
    }

    private func detailedErrorDescription(_ error: Error) -> String {
        let nsError = error as NSError
        var parts = [nsError.localizedDescription]

        if nsError.domain == NSPOSIXErrorDomain {
            parts.append("POSIX errno \(nsError.code)")
        } else {
            parts.append("\(nsError.domain) \(nsError.code)")
        }

        return parts.joined(separator: " (") + String(repeating: ")", count: max(0, parts.count - 1))
    }

    #if DEBUG
    private func debugLog(_ message: String) {
        let line = "[CodexMenuBar] \(message)\n"
        try? FileHandle.standardError.write(contentsOf: Data(line.utf8))
    }
    #endif
}

private struct RPCResponse<Result: Decodable>: Decodable {
    let id: Int
    let result: Result?
    let error: RPCError?
}

private struct RPCError: Decodable {
    let code: Int?
    let message: String
}

private final class JSONLineReader {
    private let handle: FileHandle
    private var buffer = Data()

    init(handle: FileHandle) {
        self.handle = handle
    }

    func readLine(deadlineNanoseconds: UInt64) throws -> Data? {
        while true {
            if let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let line = buffer[..<newlineIndex]
                buffer.removeSubrange(buffer.startIndex...newlineIndex)
                return Data(line)
            }

            let now = DispatchTime.now().uptimeNanoseconds
            guard now < deadlineNanoseconds else {
                throw CodexAppServerError.timedOut(stage: "response")
            }

            let remainingNanoseconds = deadlineNanoseconds - now
            let timeoutMilliseconds = Int32(
                min(
                    UInt64(Int32.max),
                    max(1, remainingNanoseconds / 1_000_000)
                )
            )

            var descriptor = pollfd(
                fd: handle.fileDescriptor,
                events: Int16(POLLIN),
                revents: 0
            )

            let result = poll(&descriptor, 1, timeoutMilliseconds)

            if result == 0 {
                throw CodexAppServerError.timedOut(stage: "response")
            }

            if result < 0 {
                if errno == EINTR {
                    continue
                }

                throw NSError(
                    domain: NSPOSIXErrorDomain,
                    code: Int(errno)
                )
            }

            if descriptor.revents & Int16(POLLIN) != 0 {
                guard let chunk = try handle.read(upToCount: 4_096),
                      !chunk.isEmpty else {
                    guard !buffer.isEmpty else {
                        return nil
                    }

                    let line = buffer
                    buffer.removeAll(keepingCapacity: false)
                    return line
                }

                buffer.append(chunk)
                continue
            }

            if descriptor.revents & Int16(POLLHUP) != 0 {
                guard !buffer.isEmpty else {
                    return nil
                }

                let line = buffer
                buffer.removeAll(keepingCapacity: false)
                return line
            }

            if descriptor.revents & Int16(POLLERR | POLLNVAL) != 0 {
                throw CodexAppServerError.unexpectedEndOfOutput
            }
        }
    }
}
