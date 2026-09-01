# Recommended GitHub repository settings

These settings are not stored in Git and must be applied to the repository
through GitHub.

## Protect `main`

The maintainer can apply the recommended classic branch protection with:

```bash
bash scripts/configure-main-protection.sh
```

The script requires an authenticated GitHub CLI session with repository
administration permission.

Equivalent settings in the GitHub UI are:

- require a pull request before merging
- require the `build-and-test` CI status check
- require branches to be up to date before merging
- block force pushes
- block branch deletion
- allow repository administrators to bypass only for emergency recovery

Optional but recommended:

- require linear history
- automatically delete head branches after merge

The release workflow should continue to run only from commits that have already
landed on `main`.

## Security

Enable **Private vulnerability reporting** under:

`Settings → Security → Code security and analysis`

This makes the reporting path documented in `SECURITY.md` available to users.


## Backfill the current release notes

The release workflow now generates useful notes automatically. The already
published `v0.2.2` release predates that change.

After merging this branch, refresh its release notes once with:

```bash
git switch main
git pull
bash scripts/backfill-release-notes.sh v0.2.2
```

The script uses the authenticated GitHub CLI and generates notes from commits
between `v0.2.1` and `v0.2.2`.
