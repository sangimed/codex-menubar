import XCTest
@testable import CodexMenuBarCore

final class CodexExecutableResolverTests:
    XCTestCase
{
    private let home = "/Users/tester"

    func testExecutableOverrideWins() throws {
        let resolver = makeResolver(
            environment: [
                "CODEX_EXECUTABLE":
                    "/custom/codex",
                "PATH": "/other/bin"
            ],
            executables: [
                "/custom/codex",
                "/other/bin/codex"
            ]
        )

        XCTAssertEqual(
            try resolver.resolve(),
            "/custom/codex"
        )
    }

    func testFindsCodexFromInheritedPath()
        throws
    {
        let resolver = makeResolver(
            environment: [
                "PATH":
                    "/custom/bin:/usr/bin"
            ],
            executables: [
                "/custom/bin/codex"
            ]
        )

        XCTAssertEqual(
            try resolver.resolve(),
            "/custom/bin/codex"
        )
    }

    func testFindsStandaloneInstallerCodex()
        throws
    {
        let expected =
            "\(home)/.codex/packages/standalone/current/bin/codex"

        let resolver = makeResolver(
            environment: [:],
            executables: [expected]
        )

        XCTAssertEqual(
            try resolver.resolve(),
            expected
        )
    }

    func testFindsNewestNVMInstall()
        throws
    {
        let nvm =
            "\(home)/.nvm/versions/node"
        let expected =
            "\(nvm)/v22.1.0/bin/codex"

        let resolver = makeResolver(
            environment: [:],
            executables: [expected],
            directories: [
                nvm: [
                    "v20.15.0",
                    "v22.1.0"
                ]
            ]
        )

        XCTAssertEqual(
            try resolver.resolve(),
            expected
        )
    }

    func testGUIProcessEnvironmentIncludesRuntimePaths()
    {
        let executable =
            "\(home)/.nvm/versions/node/v22.1.0/bin/codex"

        let resolver = makeResolver(
            environment: [
                "PATH":
                    "/custom/bin:/usr/bin"
            ],
            executables: [executable]
        )

        let environment =
            resolver.processEnvironment(
                for: executable
            )

        let paths =
            environment["PATH"]?
            .split(separator: ":")
            .map(String.init)
            ?? []

        XCTAssertEqual(
            paths.first,
            "\(home)/.nvm/versions/node/v22.1.0/bin"
        )
        XCTAssertTrue(
            paths.contains(
                "\(home)/.local/bin"
            )
        )
        XCTAssertTrue(
            paths.contains(
                "\(home)/.volta/bin"
            )
        )
        XCTAssertTrue(
            paths.contains(
                "/opt/homebrew/bin"
            )
        )
        XCTAssertTrue(
            paths.contains(
                "/custom/bin"
            )
        )
        XCTAssertFalse(
            paths.contains {
                $0.contains("(home)")
            }
        )
        XCTAssertEqual(
            paths.filter {
                $0 == "/usr/bin"
            }.count,
            1
        )
    }

    func testThrowsWhenCodexCannotBeFound()
    {
        let resolver = makeResolver(
            environment: [:],
            executables: []
        )

        XCTAssertThrowsError(
            try resolver.resolve()
        ) { error in
            XCTAssertEqual(
                error
                    as? CodexAppServerError,
                .codexNotFound
            )
        }
    }

    private func makeResolver(
        environment:
            [String: String],
        executables:
            Set<String>,
        directories:
            [String: [String]] = [:]
    ) -> CodexExecutableResolver {
        CodexExecutableResolver(
            environment: environment,
            homeDirectory: home,
            isExecutable: {
                executables.contains($0)
            },
            directoryContents: {
                directories[$0] ?? []
            }
        )
    }
}
