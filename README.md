# GemXray

[![Gem Version](https://badge.fury.io/rb/gemxray.svg)](https://badge.fury.io/rb/gemxray)
[![CI](https://github.com/ydah/gemxray/actions/workflows/main.yml/badge.svg)](https://github.com/ydah/gemxray/actions/workflows/main.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A CLI that highlights gems you can likely remove from a Ruby project's `Gemfile`, checks license compliance, and detects archived dependencies.

GemXray combines five analyzers to find issues in your Gemfile:

| Analyzer | What it detects | Default |
| --- | --- | --- |
| `unused` | No `require`, constant reference, gemspec dependency, or Rails autoload signal was found. | On |
| `redundant` | Another top-level gem already brings the gem in through `Gemfile.lock`. | On |
| `version` | The gem is already covered by your Ruby or Rails version (default/bundled gem). | On |
| `license` | Gem license is not in the configured allowed list or is unknown. | Off |
| `archive` | Gem's source repository on GitHub has been archived. | Off |

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Commands](#commands)
  - [Shared analysis options](#shared-analysis-options)
  - [`scan`](#scan)
  - [`clean`](#clean)
  - [`pr`](#pr)
  - [`list-licenses`](#list-licenses)
  - [`init`](#init)
  - [`version`](#version)
  - [`help`](#help)
- [Severity](#severity)
- [Configuration](#configuration)
  - [License fields](#license-fields)
  - [Archive fields](#archive-fields)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

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
bundle exec gemxray scan --only license,archive
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

If you run `gemxray` without a command, it behaves as `gemxray scan`.

| Command | Purpose | Useful options |
| --- | --- | --- |
| `scan` | Analyze the Gemfile and print findings. | `--format`, `--only`, `--severity`, `--ci`, `--fail-on`, `--gemfile`, `--config` |
| `clean` | Remove selected gems from `Gemfile`. | `--dry-run`, `--auto-fix`, `--comment`, `--[no-]bundle` |
| `pr` | Create a branch, commit the cleanup, and open a GitHub PR. | `--per-gem`, `--[no-]bundle`, `--comment` |
| `list-licenses` | List licenses for all gems in the Gemfile. | `--format`, `--gemfile`, `--config` |
| `init` | Write a starter `.gemxray.yml`. | `--force` |
| `version` | Print the installed gemxray version. | none |
| `help` | Print top-level help. | none |

### Shared analysis options

`scan`, `clean`, and `pr` all build the same report first, so the options below change which findings are available to print, remove, or turn into pull requests.

- `--gemfile PATH`
  Selects the target Gemfile. This also changes the project root used for file edits, `bundle install`, and git operations, because the project root is derived from the Gemfile directory.
- `--config PATH`
  Loads a specific `.gemxray.yml` instead of the default file in the current working directory.
- `--only unused,redundant,version,license,archive`
  Restricts analysis to the listed analyzers. This accepts a comma-separated list. For example, `--only unused` means `clean` and `pr` only act on unused-gem findings. Using `--only` with `license` or `archive` enables those analyzers even if they are not enabled in config.
- `--severity info|warning|danger`
  Filters the report to findings at or above the selected severity. This happens before command-specific behavior, so hidden findings are also excluded from `clean`, `pr`, and `scan --ci`.
- `--format terminal|json|yaml`
  Controls output format for `scan`. `clean` and `pr` currently accept the option because they share the same parser, but they do not render the report, so `--format` has no visible effect on those commands today.
- `--ci`
  Only changes `scan`. When enabled, `scan` exits with status `1` if any reported finding matches `--fail-on` or `ci_fail_on` from config. `clean` and `pr` currently accept the flag but do not use it.
- `--fail-on info|warning|danger`
  Only changes `scan`, and only matters together with `--ci`. It sets the minimum reported severity that should return exit code `1`. `clean` and `pr` currently accept the flag but do not use it.
- `-h`, `--help`
  Prints help for the current command and exits with status `0`.

### `scan`

`scan` analyzes the target project, formats the resulting report, prints it to standard output, and exits without changing any files.

Behavior:

- It runs the selected analyzers, merges findings per gem, applies severity overrides, filters the report by `--severity`, and sorts results by severity and gem name.
- With `--format terminal`, it prints a human-readable tree. With `json` or `yaml`, it prints machine-readable output including summary counts.
- Without `--ci`, a successful scan exits with status `0` even if findings exist.
- With `--ci`, the exit status becomes `1` when any reported finding reaches `--fail-on` or `ci_fail_on`.

```bash
bundle exec gemxray scan
bundle exec gemxray scan --format json --ci --fail-on danger
bundle exec gemxray scan --only unused --severity warning
```

### `clean`

`clean` runs the same analysis pipeline as `scan`, then edits the Gemfile based on the reported results.

Behavior:

- Without `--auto-fix`, it prompts once per reported result: `Remove <gem> (<severity>)? [y/N]:`.
- Only `y` and `yes` remove the gem. Any other answer skips it.
- It edits the full detected source range, so multiline gem declarations are removed as a unit.
- It writes a backup file at `Gemfile.bak` before saving changes.
- If nothing is selected, it prints `No removable gems were selected.` and exits with status `0`.

Command-specific options:

- `--auto-fix` -- Skips prompts and removes every reported `danger` finding automatically. `warning` and `info` findings are never auto-removed.
- `--dry-run` -- Does not write the Gemfile. Instead, it prints the selected candidates and a preview hunk showing the lines that would be removed or replaced.
- `--comment` -- Replaces each removed gem entry with a comment such as `# Removed by gemxray: ...` instead of deleting the lines outright.
- `--bundle`, `--no-bundle` -- After a real edit, `--bundle` runs `bundle install` in the target project. It is skipped automatically during `--dry-run` and when no gems were actually removed.

```bash
bundle exec gemxray clean
bundle exec gemxray clean --auto-fix --severity danger
bundle exec gemxray clean --dry-run --comment
```

### `pr`

`pr` runs the same analysis pipeline as `scan`, edits the Gemfile, commits the changes on a new branch, pushes the branch, and opens a GitHub pull request.

Behavior:

- It fails if the report is empty after filters are applied.
- It requires the target project to be inside a git repository with a clean worktree before it starts.
- It switches to `github.base_branch`, creates a cleanup branch, edits the Gemfile, commits the change, optionally refreshes `Gemfile.lock`, pushes the branch, and opens a PR.
- It tries `gh pr create` first. If `gh` is unavailable, it falls back to the GitHub API when `GH_TOKEN` or `GITHUB_TOKEN` is set.
- The PR body includes removed gems, detection reasons, and a short checklist.

Command-specific options:

- `--per-gem` -- Creates one branch and one pull request per reported gem instead of grouping everything into a single cleanup PR.
- `--comment` -- Leaves comments in the Gemfile instead of deleting lines, using the same replacement behavior as `clean --comment`.
- `--bundle`, `--no-bundle` -- Controls whether `pr` runs `bundle install` before committing. The default is `--bundle` (from `github.bundle_install: true`).

```bash
bundle exec gemxray pr
bundle exec gemxray pr --per-gem --no-bundle
bundle exec gemxray pr --only unused --severity danger
```

### `list-licenses`

`list-licenses` shows the license of every gem declared in the Gemfile.

Behavior:

- It parses the Gemfile and fetches license metadata for each gem, first from the locally installed gemspec and then from the RubyGems API as a fallback.
- With `--format terminal` (default), it prints a human-readable table with gem name, version, and license(s).
- With `--format json` or `--format yaml`, it prints machine-readable output including source and homepage.
- Gems with no license metadata are shown as `(unknown)`.

```bash
bundle exec gemxray list-licenses
bundle exec gemxray list-licenses --format json
bundle exec gemxray list-licenses --gemfile path/to/Gemfile
```

### `init`

`init` writes a starter `.gemxray.yml` into the current working directory.

- It does not read `--config`; it always writes `.gemxray.yml` in the directory where you run the command.
- If the file already exists, the command fails unless you pass `--force`.

```bash
bundle exec gemxray init
bundle exec gemxray init --force
```

### `version`

Prints the installed gemxray version and exits with status `0`.

```bash
bundle exec gemxray version
```

### `help`

Prints the top-level command summary and exits with status `0`.

```bash
bundle exec gemxray help
bundle exec gemxray --help
bundle exec gemxray scan --help
```

## Severity

| Level | Meaning | Auto-fix target |
| --- | --- | --- |
| `danger` | High-confidence removal candidate, license violation, or unknown license (when `deny_unknown` is enabled). | Yes (`clean --auto-fix` removes these) |
| `warning` | Likely removable, archived repository, or unknown license. Worth a quick review. | No |
| `info` | Informative hint (pinned versions, lower-confidence redundancy). | No |

## Configuration

`gemxray` reads `.gemxray.yml` from the working directory unless you pass `--config PATH`.

The effective config is built in this order:

1. Built-in defaults
2. `.gemxray.yml`
3. CLI options for the current run

Later scalar values override earlier ones. Array values (`scan_dirs`, `whitelist`, `github.labels`, `github.reviewers`) are merged and deduplicated.

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

license:
  enabled: false
  allowed:
    - MIT
    - Apache-2.0
    - BSD-2-Clause
    - BSD-3-Clause
    - ISC
    - Ruby
  deny_unknown: false

archive:
  enabled: false
  github_token_env: GITHUB_TOKEN
```

### Top-level fields

| Field | Default | Description |
| --- | --- | --- |
| `version` | `1` | Schema marker for future compatibility. Currently accepted but does not change behavior. |
| `gemfile_path` | `Gemfile` | Path to the target Gemfile. Expanded from the current working directory. |
| `format` | `terminal` | Output format for `scan`. Accepted: `terminal`, `json`, `yaml`. |
| `only` | all | Restricts analysis to listed analyzers: `unused`, `redundant`, `version`, `license`, `archive`. |
| `severity` | `info` | Minimum severity kept in the report. Also limits what `clean`, `pr`, and `scan --ci` can act on. |
| `ci` | `false` | Enables CI-style exit codes for `scan`. |
| `ci_fail_on` | `warning` | Minimum severity that makes `scan --ci` exit with status `1`. |
| `auto_fix` | `false` | When `true`, `clean` removes `danger` findings without prompting. |
| `dry_run` | `false` | When `true`, `clean` previews changes without writing the Gemfile. |
| `comment` | `false` | When `true`, gem entries are replaced with comments instead of being deleted. |
| `bundle_install` | `false` | When `true`, `clean` runs `bundle install` after editing. Does not affect `pr`. |
| `whitelist` | `[]` | Gem names to skip completely. |
| `scan_dirs` | `[]` | Extra directories added to the built-in scan roots (`app`, `lib`, `config`, `db`, `script`, `bin`, `exe`, `spec`, `test`, `tasks`). |
| `redundant_depth` | `2` | Maximum dependency depth for the `redundant` analyzer in `Gemfile.lock`. |
| `overrides` | `{}` | Per-gem overrides keyed by gem name. |

### Override fields

`overrides.<gem>.severity` accepts `ignore`, `info`, `warning`, or `danger`.

- `ignore` skips the gem before analysis (no finding is produced).
- `info`, `warning`, `danger` force the final reported severity after analyzers run.

### GitHub fields

| Field | Default | Description |
| --- | --- | --- |
| `github.base_branch` | `main` | Base branch that `pr` checks out before creating the cleanup branch. |
| `github.labels` | `["dependencies", "cleanup"]` | Labels applied to created PRs. Custom labels are added to defaults (arrays are merged). |
| `github.reviewers` | `[]` | Reviewers requested on created PRs. |
| `github.per_gem` | `false` | When `true`, `pr` creates one branch and one PR per gem. |
| `github.bundle_install` | `true` | Controls whether `pr` runs `bundle install` before committing. |

### License fields

The `license` analyzer is opt-in. Enable it in config or pass `--only license`.

| Field | Default | Description |
| --- | --- | --- |
| `license.enabled` | `false` | Include the `license` analyzer in default scans. |
| `license.allowed` | `[]` | SPDX identifiers or license names that are permitted. Matching is case-insensitive and uses fingerprint normalization (e.g. `"The MIT License"` matches `"MIT"`). When empty, only unknown-license detection applies. |
| `license.deny_unknown` | `false` | When `true`, gems with no license metadata are reported as `danger` instead of `warning`. |

### Archive fields

The `archive` analyzer is opt-in. Enable it in config or pass `--only archive`.

| Field | Default | Description |
| --- | --- | --- |
| `archive.enabled` | `false` | Include the `archive` analyzer in default scans. |
| `archive.github_token_env` | `GITHUB_TOKEN` | Name of the environment variable containing a GitHub personal access token. The token is used to query the GitHub API for repository archive status. Without a token, public repositories can still be checked but rate limits are stricter. |
| `archive.overrides` | `{}` | Manual gem-to-repository mappings (`gem_name: "owner/repo"`) for gems whose metadata does not point to the correct GitHub repository. |

## Development

```bash
bundle install
bundle exec rspec
```

Run the executable locally:

```bash
ruby exe/gemxray scan --format terminal
```

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/ydah/gemxray).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
