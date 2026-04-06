# Changelog

## Unreleased

## 0.2.0 (2026-04-06)

- Add `--fail-on` option and `ci_fail_on` config field to control the minimum severity that causes `scan --ci` to exit with status 1. Previously, any finding triggered a failure; now only findings at or above the specified level do. The default is `warning`.

## 0.1.0 (2026-03-27)

- Initial release.