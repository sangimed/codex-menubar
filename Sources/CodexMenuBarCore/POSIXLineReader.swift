import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

final class POSIXLineReader {
    private let fileDescriptor: Int32
    private var buffer = Data()

    init(fileDescriptor: Int32) {
        self.fileDescriptor = fileDescriptor
    }

    func readLine(
        timeout: TimeInterval?,
        timeoutStage: String
    ) throws -> Data? {
        let deadlineNanoseconds = timeout.map {
            DispatchTime.now().uptimeNanoseconds
                + UInt64($0 * 1_000_000_000)
        }

        while true {
            if let newlineIndex =
                buffer.firstIndex(of: 0x0A)
            {
                let line =
                    buffer[..<newlineIndex]
                buffer.removeSubrange(
                    buffer.startIndex
                    ...newlineIndex
                )
                return Data(line)
            }

            let timeoutMilliseconds: Int32

            if let deadlineNanoseconds {
                let now =
                    DispatchTime.now()
                    .uptimeNanoseconds

                guard now
                    < deadlineNanoseconds
                else {
                    throw
                        CodexAppServerError
                        .timedOut(
                            stage:
                                timeoutStage
                        )
                }

                let remainingMilliseconds =
                    max(
                        1,
                        (
                            deadlineNanoseconds
                            - now
                        ) / 1_000_000
                    )

                timeoutMilliseconds =
                    Int32(
                        min(
                            UInt64(
                                Int32.max
                            ),
                            remainingMilliseconds
                        )
                    )
            } else {
                timeoutMilliseconds = -1
            }

            var descriptor = pollfd(
                fd: fileDescriptor,
                events: Int16(POLLIN),
                revents: 0
            )

            let pollResult = poll(
                &descriptor,
                1,
                timeoutMilliseconds
            )

            if pollResult == 0 {
                throw
                    CodexAppServerError
                    .timedOut(
                        stage:
                            timeoutStage
                    )
            }

            if pollResult < 0 {
                if errno == EINTR {
                    continue
                }

                throw NSError(
                    domain:
                        NSPOSIXErrorDomain,
                    code: Int(errno)
                )
            }

            if descriptor.revents
                & Int16(POLLIN) != 0
            {
                var bytes = [UInt8](
                    repeating: 0,
                    count: 4_096
                )

                let bytesRead =
                    bytes
                    .withUnsafeMutableBytes {
                        rawBuffer in

                        read(
                            fileDescriptor,
                            rawBuffer
                                .baseAddress,
                            rawBuffer.count
                        )
                    }

                if bytesRead > 0 {
                    buffer.append(
                        contentsOf:
                            bytes.prefix(
                                Int(
                                    bytesRead
                                )
                            )
                    )
                    continue
                }

                if bytesRead == 0 {
                    if buffer.isEmpty {
                        return nil
                    }

                    let line = buffer
                    buffer.removeAll(
                        keepingCapacity:
                            false
                    )
                    return line
                }

                if errno == EINTR {
                    continue
                }

                throw NSError(
                    domain:
                        NSPOSIXErrorDomain,
                    code: Int(errno)
                )
            }

            if descriptor.revents
                & Int16(POLLHUP) != 0
            {
                if buffer.isEmpty {
                    return nil
                }

                let line = buffer
                buffer.removeAll(
                    keepingCapacity:
                        false
                )
                return line
            }

            if descriptor.revents
                & Int16(
                    POLLERR
                    | POLLNVAL
                ) != 0
            {
                throw
                    CodexAppServerError
                    .unexpectedEndOfOutput
            }
        }
    }
}
