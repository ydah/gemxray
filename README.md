# GemXray

`gemxray` is a CLI that highlights gems you can likely remove from a Ruby project's `Gemfile`.

It combines three analyzers:

1. `unused`: no `require`, constant reference, gemspec dependency, or Rails autoload signal was found.
2. `redundant`: another top-level gem already brings the gem in through `Gemfile.lock`.
3. `version-redundant`: the gem is already covered by your Ruby or Rails version.

If you run `gemxray` without a command, it defaults to `scan`.

## Installation

Add the gem to your toolchain:

```bash
bundle add gemxray --group development
```

Or install it directly:

```bash
gem install gemxray
```

If you install the gem globally, replace `bundle exec gemxray` with `gemxray` in the examples below.

## Quick Start

Generate a starter config:

```bash
bundle exec gemxray init
```

Scan the current project:

```bash
bundle exec gemxray scan
```

Use structured output for CI or scripts:

```bash
bundle exec gemxray scan --format json --ci --fail-on danger
bundle exec gemxray scan --only unused,version --severity warning
```

Preview or apply Gemfile cleanup:

```bash
bundle exec gemxray clean --dry-run
bundle exec gemxray clean
bundle exec gemxray clean --auto-fix
```

Create a cleanup branch and open a pull request:

```bash
bundle exec gemxray pr
bundle exec gemxray pr --per-gem --no-bundle
```

Target a different project by passing a Gemfile path:

```bash
bundle exec gemxray scan --gemfile path/to/Gemfile
```

## Commands

| Command | Purpose | Useful options |
| --- | --- | --- |
| `scan` | Analyze the Gemfile and print findings. | `--format`, `--only`, `--severity`, `--ci`, `--fail-on`, `--gemfile`, `--config` |
| `clean` | Remove selected gems from `Gemfile`. | `--dry-run`, `--auto-fix`, `--comment`, `--[no-]bundle` |
| `pr` | Create a branch, commit the cleanup, and open a GitHub PR. | `--per-gem`, `--[no-]bundle`, `--comment` |
| `init` | Write a starter `.gemxray.yml`. | `--force` |
| `version` | Print the installed gemxray version. | none |

## Severity

- `danger`: high-confidence removal candidate. `clean --auto-fix` only removes `danger` findings.
- `warning`: likely removable, but worth a quick review.
- `info`: informative hint, often tied to pinned versions or lower-confidence redundancy.

## Configuration

`gemxray` reads `.gemxray.yml` from the working directory unless you pass `--config PATH`.

```yaml
version: 1

ci: false
ci_fail_on: warning

whitelist:
  - bootsnap
  - tzinfo-data

scan_dirs:
  - engines/billing/app
  - engines/billing/lib

redundant_depth: 2

overrides:
  puma:
    severity: ignore

github:
  base_branch: main
  labels:
    - dependencies
    - cleanup
  reviewers: []
  per_gem: false
  bundle_install: true
```

Config fields:

- `ci`: enable non-zero exit status for `scan`.
- `ci_fail_on`: minimum reported severity that makes `scan --ci` exit with status `1`. Defaults to `warning`.
- `whitelist`: gems to skip entirely.
- `scan_dirs`: extra directories to scan in addition to the defaults: `app`, `lib`, `config`, `db`, `script`, `bin`, `exe`, `spec`, `test`, and `tasks`.
- `redundant_depth`: maximum dependency depth for redundant gem detection.
- `overrides.<gem>.severity`: override a finding severity with `ignore`, `info`, `warning`, or `danger`.
- `github.*`: defaults used by `pr`.

## Notes

- `clean` writes `Gemfile.bak` before editing the file.
- `clean` removes the full source range for multiline gem declarations.
- `clean --bundle` runs `bundle install` after editing.
- `pr` runs `bundle install` before committing by default. Use `pr --no-bundle` to skip it.
- `pr` requires a clean git worktree before it creates branches or commits.
- `pr` switches to `github.base_branch` before creating the cleanup branch.
- If `gh` is unavailable, `pr` falls back to the GitHub API when `GH_TOKEN` or `GITHUB_TOKEN` is set.
- Ruby default and bundled gem checks use cached stdgems data when available and bundled offline data otherwise.
- Rails version hints come from the bundled `data/rails_changes.yml` dataset.

## Development

Install dependencies and run the test suite:

```bash
bundle install
bundle exec rspec
```

Run the executable locally:

```bash
ruby exe/gemxray scan --format terminal
```
