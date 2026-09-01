import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public final class CodexAppServerClient: @unchecked Sendable {
    public typealias UsageHandler = @Sendable (CodexUsageSummary) -> Void

    private let initializeTimeout: TimeInterval
    private let stateLock = NSLock()
    private let writeLock = NSLock()

    private var sessionActive = false
    private var process: Process?
    private var inputHandle: FileHandle?
    private var initialized = false
    private var nextRequestID = 3

    public init(initializeTimeout: TimeInterval = 15) {
        self.initializeTimeout = initializeTimeout

        #if canImport(Darwin)
        signal(SIGPIPE, SIG_IGN)
        #endif
    }

    public func runSession(onUsage: @escaping UsageHandler) async throws {
        try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            try self.runSessionSynchronously(onUsage: onUsage)
                            continuation.resume(returning: ())
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            },
            onCancel: {
                self.stop()
            }
        )
    }

    public func requestRefresh() throws {
        let handle: FileHandle
        let requestID: Int

        stateLock.lock()
        guard initialized, let currentHandle = inputHandle else {
            stateLock.unlock()
            throw CodexAppServerError.notConnected
        }

        handle = currentHandle
        requestID = nextRequestID
        nextRequestID += 1
        stateLock.unlock()

        try sendMessages(
            [[
                "method": "account/rateLimits/read",
                "id": requestID
            ]],
            stage: "account/rateLimits/read",
            to: handle
        )

        #if DEBUG
        debugLog("Requested rate-limit refresh id=\(requestID)")
        #endif
    }

    public func stop() {
        let currentProcess: Process?
        let currentInput: FileHandle?

        stateLock.lock()
        initialized = false
        currentProcess = process
        currentInput = inputHandle
        inputHandle = nil
        stateLock.unlock()

        try? currentInput?.close()

        if let currentProcess, currentProcess.isRunning {
            currentProcess.terminate()
        }
    }

    private func runSessionSynchronously(
        onUsage: @escaping UsageHandler
    ) throws {
        try reserveSession()

        let resolver =
            CodexExecutableResolver()

        let executable: String
        do {
            executable = try resolver.resolve()
        } catch {
            releaseSessionReservation()
            throw error
        }

        #if DEBUG
        debugLog("Using Codex executable: \(executable)")
        #endif

        let child = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()

        child.executableURL = URL(fileURLWithPath: executable)
        child.arguments = ["app-server", "--stdio"]
        child.environment =
            resolver.processEnvironment(
                for: executable
            )
        child.standardInput = inputPipe
        child.standardOutput = outputPipe
        child.standardError = FileHandle.standardError

        do {
            try child.run()
        } catch {
            releaseSessionReservation()
            throw CodexAppServerError.codexNotFound
        }

        registerSession(
            process: child,
            inputHandle: inputPipe.fileHandleForWriting
        )

        defer {
            cleanupSession(
                process: child,
                inputHandle: inputPipe.fileHandleForWriting
            )
        }

        let reader = POSIXLineReader(
            fileDescriptor: outputPipe.fileHandleForReading.fileDescriptor
        )

        try sendMessages(
            [[
                "method": "initialize",
                "id": 1,
                "params": [
                    "clientInfo": [
                        "name": "codex-menubar",
                        "title": "CodexMenuBar",
                        "version":
                            clientVersion
                    ],
                    "capabilities": [
                        "optOutNotificationMethods": [
                            "remoteControl/status/changed"
                        ]
                    ]
                ]
            ]],
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

        try sendMessages(
            [
                ["method": "initialized"],
                [
                    "method": "account/rateLimits/read",
                    "id": 2
                ]
            ],
            stage: "initialized + initial account/rateLimits/read",
            to: inputPipe.fileHandleForWriting
        )

        markInitialized(
            process: child,
            inputHandle: inputPipe.fileHandleForWriting
        )

        #if DEBUG
        debugLog("Persistent app-server session ready")
        #endif

        while true {
            let line: Data

            do {
                guard let nextLine = try reader.readLine(
                    timeout: nil,
                    timeoutStage: "app-server event"
                ) else {
                    throw CodexAppServerError.unexpectedEndOfOutput
                }
                line = nextLine
            } catch let error as CodexAppServerError {
                throw error
            } catch {
                throw CodexAppServerError.transportReadFailed(
                    stage: "app-server event",
                    message: detailedErrorDescription(error)
                )
            }

            guard !line.isEmpty else {
                continue
            }

            try handleIncomingMessage(
                line,
                onUsage: onUsage
            )
        }
    }

    private func handleIncomingMessage(
        _ data: Data,
        onUsage: UsageHandler
    ) throws {
        guard
            let object = try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
        else {
            throw CodexAppServerError.malformedResponse
        }

        if let error = object["error"] as? [String: Any] {
            throw CodexAppServerError.rpcError(
                code: (error["code"] as? NSNumber)?.intValue,
                message: error["message"] as? String ?? "Unknown error"
            )
        }

        if let responseID = object["id"] as? NSNumber {
            #if DEBUG
            debugLog("Received JSON-RPC response id=\(responseID.intValue)")
            #endif

            if let response = try? JSONDecoder().decode(
                RPCResponse<RateLimitsResponse>.self,
                from: data
            ), let result = response.result {
                onUsage(CodexUsageSummary(response: result))
            }

            return
        }

        guard let method = object["method"] as? String else {
            return
        }

        #if DEBUG
        debugLog("Received notification \(method)")
        #endif

        guard method == "account/rateLimits/updated" else {
            return
        }

        let notification = try JSONDecoder().decode(
            RateLimitsUpdatedNotification.self,
            from: data
        )

        onUsage(
            CodexUsageSummary(
                response: RateLimitsResponse(
                    rateLimits: notification.params.rateLimits,
                    rateLimitsByLimitId: nil
                )
            )
        )
    }

    private func reserveSession() throws {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard !sessionActive else {
            throw CodexAppServerError.sessionAlreadyRunning
        }

        sessionActive = true
        initialized = false
        nextRequestID = 3
    }

    private func releaseSessionReservation() {
        stateLock.lock()
        sessionActive = false
        initialized = false
        stateLock.unlock()
    }

    private func registerSession(
        process: Process,
        inputHandle: FileHandle
    ) {
        stateLock.lock()
        self.process = process
        self.inputHandle = inputHandle
        stateLock.unlock()
    }

    private func markInitialized(
        process: Process,
        inputHandle: FileHandle
    ) {
        stateLock.lock()

        if self.process === process,
           self.inputHandle === inputHandle {
            initialized = true
        }

        stateLock.unlock()
    }

    private func cleanupSession(
        process: Process,
        inputHandle: FileHandle
    ) {
        try? inputHandle.close()

        if process.isRunning {
            process.terminate()
        }

        stateLock.lock()

        if self.process === process {
            self.process = nil
            self.inputHandle = nil
            initialized = false
        }

        sessionActive = false
        stateLock.unlock()
    }

    private var clientVersion: String {
        guard
            let version =
                Bundle.main
                .object(
                    forInfoDictionaryKey:
                        "CFBundleShortVersionString"
                ) as? String,
            !version.isEmpty
        else {
            return "dev"
        }

        return version
    }

    private func sendMessages(
        _ objects: [[String: Any]],
        stage: String,
        to handle: FileHandle
    ) throws {
        writeLock.lock()
        defer { writeLock.unlock() }

        do {
            var payload = Data()

            for object in objects {
                payload.append(
                    try JSONSerialization.data(withJSONObject: object)
                )
                payload.append(0x0A)
            }

            try handle.write(contentsOf: payload)
        } catch {
            throw CodexAppServerError.transportWriteFailed(
                stage: stage,
                message: detailedErrorDescription(error)
            )
        }
    }

    private func readResponse(
        id expectedID: Int,
        from reader: POSIXLineReader,
        timeout: TimeInterval,
        stage: String
    ) throws -> Data {
        while true {
            let line: Data

            do {
                guard let nextLine = try reader.readLine(
                    timeout: timeout,
                    timeoutStage: stage
                ) else {
                    throw CodexAppServerError.unexpectedEndOfOutput
                }
                line = nextLine
            } catch let error as CodexAppServerError {
                throw error
            } catch {
                throw CodexAppServerError.transportReadFailed(
                    stage: stage,
                    message: detailedErrorDescription(error)
                )
            }

            guard !line.isEmpty else {
                continue
            }

            guard
                let object = try JSONSerialization.jsonObject(with: line)
                    as? [String: Any]
            else {
                throw CodexAppServerError.malformedResponse
            }

            if let id = object["id"] as? NSNumber,
               id.intValue == expectedID {
                return line
            }
        }
    }

    private func throwIfRPCError(in data: Data) throws {
        guard
            let object = try JSONSerialization.jsonObject(with: data)
                as? [String: Any]
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
        return "\(nsError.localizedDescription) [\(nsError.domain) \(nsError.code)]"
    }

    #if DEBUG
    private func debugLog(_ message: String) {
        let line = "[CodexMenuBar] \(message)\n"
        try? FileHandle.standardError.write(contentsOf: Data(line.utf8))
    }
    #endif
}
