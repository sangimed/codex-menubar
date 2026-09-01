import Foundation

struct CodexExecutableResolver {
    private let environment: [String: String]
    private let homeDirectory: String
    private let isExecutable: (String) -> Bool
    private let directoryContents: (String) -> [String]

    init(
        environment: [String: String] =
            ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        homeDirectory: String? = nil
    ) {
        self.environment = environment
        self.homeDirectory =
            homeDirectory
            ?? fileManager.homeDirectoryForCurrentUser.path
        self.isExecutable = {
            fileManager.isExecutableFile(atPath: $0)
        }
        self.directoryContents = {
            (try? fileManager.contentsOfDirectory(
                atPath: $0
            )) ?? []
        }
    }

    init(
        environment: [String: String],
        homeDirectory: String,
        isExecutable: @escaping (String) -> Bool,
        directoryContents: @escaping (String) -> [String]
    ) {
        self.environment = environment
        self.homeDirectory = homeDirectory
        self.isExecutable = isExecutable
        self.directoryContents = directoryContents
    }

    func resolve() throws -> String {
        if let override =
            environment["CODEX_EXECUTABLE"],
           isExecutable(override)
        {
            return override
        }

        if let executable =
            candidatePaths()
            .first(where: isExecutable)
        {
            return executable
        }

        throw CodexAppServerError.codexNotFound
    }

    func processEnvironment(
        for executable: String
    ) -> [String: String] {
        var childEnvironment = environment

        let executableDirectory =
            URL(fileURLWithPath: executable)
            .deletingLastPathComponent()
            .path

        var pathEntries: [String] = [
            executableDirectory,
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "\(homeDirectory)/.local/bin",
            "\(homeDirectory)/.npm-global/bin",
            "\(homeDirectory)/.volta/bin",
            "\(homeDirectory)/.asdf/shims",
            "\(homeDirectory)/.local/share/mise/shims",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]

        if let inheritedPath =
            environment["PATH"]
        {
            pathEntries.append(
                contentsOf:
                    inheritedPath
                    .split(separator: ":")
                    .map(String.init)
            )
        }

        var seen = Set<String>()
        childEnvironment["PATH"] =
            pathEntries
            .filter {
                !$0.isEmpty
                    && seen.insert($0)
                    .inserted
            }
            .joined(separator: ":")

        return childEnvironment
    }

    func candidatePaths() -> [String] {
        var candidates: [String] = []

        if let path = environment["PATH"] {
            candidates.append(
                contentsOf:
                    path
                    .split(separator: ":")
                    .map { "\($0)/codex" }
            )
        }

        candidates.append(contentsOf: [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(homeDirectory)/.codex/packages/standalone/current/bin/codex",
            "\(homeDirectory)/.local/bin/codex",
            "\(homeDirectory)/.npm-global/bin/codex",
            "\(homeDirectory)/.volta/bin/codex",
            "\(homeDirectory)/.asdf/shims/codex",
            "\(homeDirectory)/.local/share/mise/shims/codex"
        ])

        let nvmVersions =
            "\(homeDirectory)/.nvm/versions/node"

        candidates.append(
            contentsOf:
                directoryContents(nvmVersions)
                .sorted(by: >)
                .map {
                    "\(nvmVersions)/\($0)/bin/codex"
                }
        )

        var seen = Set<String>()
        return candidates.filter {
            seen.insert($0).inserted
        }
    }
}
