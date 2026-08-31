# Recommended GitHub repository settings

These settings are not stored in Git. Apply them in GitHub after merging this
hardening branch.

## Protect `main`

Create a branch ruleset targeting `main` with:

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
