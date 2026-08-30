import Foundation

public enum CodexAppServerError: LocalizedError, Equatable {
    case codexNotFound
    case timedOut
    case unexpectedEndOfOutput
    case malformedResponse
    case rpcError(code: Int?, message: String)

    public var errorDescription: String? {
        switch self {
        case .codexNotFound:
            return "Codex CLI was not found. Install Codex or set CODEX_EXECUTABLE to its full path."
        case .timedOut:
            return "Codex app-server did not respond in time."
        case .unexpectedEndOfOutput:
            return "Codex app-server stopped before returning the usage limits."
        case .malformedResponse:
            return "Codex app-server returned a response that CodexMenuBar could not understand."
        case let .rpcError(code, message):
            if let code {
                return "Codex app-server error \(code): \(message)"
            }
            return "Codex app-server error: \(message)"
        }
    }
}

public final class CodexAppServerClient: @unchecked Sendable {
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 10) {
        self.timeout = timeout
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

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw CodexAppServerError.codexNotFound
        }

        let timeoutState = TimeoutState()
        let timeoutWorkItem = DispatchWorkItem {
            timeoutState.markTimedOut()
            if process.isRunning {
                process.terminate()
            }
        }

        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + timeout,
            execute: timeoutWorkItem
        )

        defer {
            timeoutWorkItem.cancel()
            inputPipe.fileHandleForWriting.closeFile()
            if process.isRunning {
                process.terminate()
            }
        }

        let reader = JSONLineReader(handle: outputPipe.fileHandleForReading)

        do {
            try send(
                [
                    "method": "initialize",
                    "id": 1,
                    "params": [
                        "clientInfo": [
                            "name": "codex-menubar",
                            "version": "0.1.0"
                        ]
                    ]
                ],
                to: inputPipe.fileHandleForWriting
            )

            let initializeResponse = try readResponse(
                id: 1,
                from: reader
            )
            try throwIfRPCError(in: initializeResponse)

            try send(
                ["method": "initialized"],
                to: inputPipe.fileHandleForWriting
            )

            try send(
                [
                    "method": "account/rateLimits/read",
                    "id": 2
                ],
                to: inputPipe.fileHandleForWriting
            )

            let rateLimitsData = try readResponse(
                id: 2,
                from: reader
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

            return CodexUsageSummary(response: result)
        } catch {
            if timeoutState.didTimeOut {
                throw CodexAppServerError.timedOut
            }
            throw error
        }
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
        to handle: FileHandle
    ) throws {
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(0x0A)
        handle.write(data)
    }

    private func readResponse(
        id expectedId: Int,
        from reader: JSONLineReader
    ) throws -> Data {
        while let line = try reader.readLine() {
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
        }

        throw CodexAppServerError.unexpectedEndOfOutput
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

private final class TimeoutState {
    private let lock = NSLock()
    private var timedOut = false

    var didTimeOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timedOut
    }

    func markTimedOut() {
        lock.lock()
        timedOut = true
        lock.unlock()
    }
}

private final class JSONLineReader {
    private let handle: FileHandle
    private var buffer = Data()

    init(handle: FileHandle) {
        self.handle = handle
    }

    func readLine() throws -> Data? {
        while true {
            if let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let line = buffer[..<newlineIndex]
                buffer.removeSubrange(buffer.startIndex...newlineIndex)
                return Data(line)
            }

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
        }
    }
}
