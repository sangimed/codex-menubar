# Releasing CodexMenuBar

CodexMenuBar can be distributed without a paid Apple Developer membership.

The free distribution path uses:

- a universal macOS app bundle (`arm64` + `x86_64`)
- ad-hoc code signing
- a ZIP archive
- a SHA-256 checksum
- GitHub Releases
- an optional Homebrew tap

Because the app is not signed with an Apple Developer ID and is not notarized,
macOS Gatekeeper may require the user to explicitly allow the app after
downloading it.

## 1. Release artifacts

For a version such as `0.2.0`, the release pipeline creates:

```text
CodexMenuBar.app
CodexMenuBar-v0.2.0-macOS.zip
CodexMenuBar-v0.2.0-macOS.zip.sha256
codex-menubar.rb
```

The ZIP contains the app bundle. The Ruby file is the generated Homebrew Cask.

## 2. Test the package locally

Before tagging a release:

```bash
git switch feat/v0.2
git pull

make test
VERSION=0.2.0 make package
```

Verify the architectures:

```bash
lipo -archs dist/CodexMenuBar.app/Contents/MacOS/CodexMenuBar
```

Expected output contains both:

```text
x86_64 arm64
```

Verify the ad-hoc signature:

```bash
codesign --verify --deep --strict --verbose=2 dist/CodexMenuBar.app
```

## 3. GitHub Release automation

The release workflow is:

```text
.github/workflows/release.yml
```

It runs when a tag beginning with `v` is pushed.

Stable example:

```bash
git tag v0.2.0
git push origin v0.2.0
```

Prerelease example:

```bash
git tag v0.2.0-beta.1
git push origin v0.2.0-beta.1
```

Tags containing a prerelease suffix are published as GitHub prereleases.

The workflow:

1. runs the Swift tests
2. builds a universal macOS app
3. applies an ad-hoc signature
4. creates the versioned ZIP
5. creates the SHA-256 checksum
6. renders the Homebrew Cask
7. creates the GitHub Release
8. uploads all release artifacts
9. optionally updates `sangimed/homebrew-tap`

## 4. Create the Homebrew tap

The tap repository only needs to be created once.

Using GitHub CLI:

```bash
gh repo create sangimed/homebrew-tap \
  --public \
  --description "Homebrew tap for Sangimed projects"
```

Homebrew maps:

```text
sangimed/tap
```

to:

```text
github.com/sangimed/homebrew-tap
```

The generated Cask is stored at:

```text
Casks/codex-menubar.rb
```

## 5. Allow the release workflow to update the tap

The normal GitHub Actions `GITHUB_TOKEN` for CodexMenuBar cannot write to a
different repository.

Create a fine-grained GitHub personal access token with **Contents: Read and
write** access only to:

```text
sangimed/homebrew-tap
```

Then save it as a repository Actions secret on `sangimed/codex-menubar`:

```bash
gh secret set HOMEBREW_TAP_TOKEN --repo sangimed/codex-menubar
```

Paste the token when prompted.

If the secret is absent, the release workflow does not fail. It simply skips
the tap update and still publishes `codex-menubar.rb` as a release asset.

## 6. Install with Homebrew

Once the tap contains the Cask:

```bash
brew tap sangimed/tap
brew install --cask codex-menubar
```

The fully qualified form is:

```bash
brew install --cask sangimed/tap/codex-menubar
```

Upgrade:

```bash
brew upgrade --cask codex-menubar
```

Uninstall:

```bash
brew uninstall --cask codex-menubar
```

To also remove CodexMenuBar's local history/preferences as defined by the Cask:

```bash
brew uninstall --zap --cask codex-menubar
```

## 7. Gatekeeper and unsigned community releases

Ad-hoc signing verifies the internal integrity of the app bundle, but it does
not give the app an Apple-trusted Developer ID identity and does not notarize
it.

On first launch, macOS may therefore block CodexMenuBar.

A user should first try opening the app normally. If macOS blocks it, use the
supported system route in **System Settings → Privacy & Security** to allow
CodexMenuBar after the blocked launch attempt.

Do not instruct users to globally disable Gatekeeper.

## 8. Moving to Developer ID later

The packaging scripts already support a real signing identity through:

```bash
CODESIGN_IDENTITY="Developer ID Application: ..." make app
```

If the project later joins the Apple Developer Program, the release workflow
can be extended with Developer ID certificates and Apple notarization without
changing the app architecture or Homebrew layout.
