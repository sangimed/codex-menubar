# Releasing CodexMenuBar

CodexMenuBar currently uses a free community distribution path:

- universal macOS app bundle (`arm64` + `x86_64`)
- ad-hoc code signing
- ZIP archive + SHA-256 checksum
- GitHub Releases
- the `sangimed/homebrew-tap` Homebrew Cask

Because community builds are not signed with an Apple Developer ID and are not
notarized, Gatekeeper may require one explicit approval on first launch.

## 1. Version source of truth

The repository root contains:

```text
VERSION
```

That file is the source of truth for local package builds and stable release
automation.

Before publishing a new release, update `VERSION` in a normal pull request,
for example:

```text
0.2.3
```

The release workflow refuses to publish a version that does not match the
`VERSION` file.

The app-server client reports the packaged app version from
`CFBundleShortVersionString`, so the Swift code does not contain a second
hard-coded release version.

## 2. Test locally

Start from an up-to-date `main`:

```bash
git switch main
git pull

make test
make package
```

Verify that the app is universal:

```bash
lipo -archs dist/CodexMenuBar.app/Contents/MacOS/CodexMenuBar
```

The output must contain both:

```text
arm64 x86_64
```

Verify the signature:

```bash
codesign --verify --deep --strict --verbose=2 dist/CodexMenuBar.app
```

## 3. Publish from GitHub Actions

The release workflow lives at:

```text
.github/workflows/release.yml
```

Recommended flow:

1. Merge the version bump and release changes into `main`.
2. Open **Actions → Release**.
3. Click **Run workflow**.
4. Select `main`.
5. Enter the exact value from `VERSION`.
6. Leave **Publish as a prerelease** disabled for stable releases.
7. Run the workflow.

Manual releases are intentionally restricted to `main`.

Tag-based releases also remain supported:

```bash
VERSION="$(cat VERSION)"
git tag "v$VERSION"
git push origin "v$VERSION"
```

A version containing a prerelease suffix is automatically marked as a
prerelease.

## 4. What the workflow does

The workflow:

1. validates the requested version against `VERSION`
2. runs the Swift tests
3. builds a universal app
4. applies an ad-hoc signature
5. creates the versioned ZIP and SHA-256 checksum
6. renders the Homebrew Cask
7. generates release notes from commits since the previous tag
8. creates the GitHub Release
9. updates `sangimed/homebrew-tap` for stable releases

Prereleases intentionally do not replace the stable Homebrew Cask.

## 5. Release artifacts

For version `0.2.2`, for example:

```text
CodexMenuBar-v0.2.2-macOS.zip
CodexMenuBar-v0.2.2-macOS.zip.sha256
codex-menubar.rb
```

The ZIP contains `CodexMenuBar.app`.

## 6. Homebrew tap

Stable releases update:

```text
sangimed/homebrew-tap
└── Casks/
    └── codex-menubar.rb
```

This is powered by the `HOMEBREW_TAP_TOKEN` repository Actions secret. The
fine-grained token only needs **Contents: Read and write** permission on
`sangimed/homebrew-tap`.

If the secret is unavailable, the GitHub Release can still be published; the
tap update is skipped.

Install:

```bash
brew install --cask sangimed/tap/codex-menubar
```

Upgrade:

```bash
brew update
brew upgrade --cask codex-menubar
```

Uninstall:

```bash
brew uninstall --cask codex-menubar
```

Remove local history and preferences too:

```bash
brew uninstall --zap --cask codex-menubar
```

## 7. Gatekeeper

Ad-hoc signing verifies bundle integrity but does not establish an
Apple-trusted Developer ID identity.

If macOS blocks the first launch, use:

**System Settings → Privacy & Security → Open Anyway**

Do not instruct users to disable Gatekeeper globally.

## 8. Developer ID later

The packaging script already accepts:

```bash
CODESIGN_IDENTITY="Developer ID Application: ..." make app
```

A future Apple Developer Program setup can add Developer ID signing and
notarization without changing the app architecture or Homebrew layout.
