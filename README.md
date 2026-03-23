# GemSweeper

`gem-sweeper` is a CLI for finding gems that can likely be removed from a project `Gemfile`.

It combines three signals:

1. Unused gems: no `require`, constant reference, gemspec dependency, or Rails auto-load signal was found.
2. Redundant gems: another top-level gem already pulls the gem in through `Gemfile.lock`.
3. Version-redundant gems: the gem is now covered by Ruby default gems or known Rails version changes.

## Installation

Add the gem to your toolchain:

```bash
bundle add gem_sweeper --group development
```

Or install it directly:

```bash
gem install gem_sweeper
```

## Usage

Run a scan in the current project:

```bash
bundle exec gem-sweeper scan
```

Use JSON or YAML output for CI or scripting:

```bash
bundle exec gem-sweeper scan --format json
bundle exec gem-sweeper scan --format yaml --ci
```

Limit the analyzers:

```bash
bundle exec gem-sweeper scan --only unused,version
```

Interactively remove candidates from `Gemfile`:

```bash
bundle exec gem-sweeper clean
```

Apply only high-confidence removals without prompting:

```bash
bundle exec gem-sweeper clean --auto-fix
```

Generate a cleanup branch and open a GitHub PR with `gh`:

```bash
bundle exec gem-sweeper pr --bundle
```

If `gh` is unavailable, the PR command can fall back to the GitHub API when `GH_TOKEN` or `GITHUB_TOKEN` is set.

Generate a starter config:

```bash
bundle exec gem-sweeper init
```

## Config

`gem-sweeper` looks for `.gem-sweeper.yml` in the working directory.

```yaml
version: 1

whitelist:
  - bootsnap
  - tzinfo-data

scan_dirs:
  - engines/billing/app
  - engines/billing/lib

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
```

## Command Summary

`scan`
: Analyze the Gemfile and print a report.

`clean`
: Remove selected gems from `Gemfile`. `--auto-fix` only removes `danger` findings.

`pr`
: Create a branch, commit Gemfile cleanup, and open a PR with GitHub CLI.

`init`
: Write `.gem-sweeper.yml`.

`version`
: Print the gem version.

## Notes

- `clean` writes `Gemfile.bak` before mutating the file.
- `clean` removes the full source range for multiline gem declarations.
- `clean --bundle` and `pr --bundle` run `bundle install` after editing.
- stdgems data uses a cached remote payload when available and falls back to bundled offline data.
- `pr` requires a clean git worktree before it creates a branch and commits.

## Development

Setup and test:

```bash
bundle install
bundle exec rspec
```

Run the executable locally:

```bash
ruby exe/gem-sweeper scan --format terminal
```
