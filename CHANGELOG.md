# Changelog

## Unreleased

## 0.3.0 (2026-04-17)

- Add `license` analyzer that checks gem licenses against a configurable allowed list. Unknown licenses are reported as `warning` by default, or `danger` when `license.deny_unknown` is enabled. License matching uses fingerprint normalization for flexible comparison (e.g. "The MIT License" matches "MIT").
- Add `archive` analyzer that detects gems whose GitHub source repository has been archived. Uses the GitHub API with configurable token via `archive.github_token_env`.
- Add `licenses` command to list all gem licenses in table, JSON, or YAML format.
- Both new analyzers run by default and can be disabled via `enabled: false` in config or excluded with `--only`.

## 0.2.0 (2026-04-06)

- Add `--fail-on` option and `ci_fail_on` config field to control the minimum severity that causes `scan --ci` to exit with status 1. Previously, any finding triggered a failure; now only findings at or above the specified level do. The default is `warning`.

## 0.1.0 (2026-03-27)

- Initial release.