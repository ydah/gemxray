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

If you run `gemxray` without a command, it behaves as `gemxray scan`.

| Command | Purpose | Useful options |
| --- | --- | --- |
| `scan` | Analyze the Gemfile and print findings. | `--format`, `--only`, `--severity`, `--ci`, `--fail-on`, `--gemfile`, `--config` |
| `clean` | Remove selected gems from `Gemfile`. | `--dry-run`, `--auto-fix`, `--comment`, `--[no-]bundle` |
| `pr` | Create a branch, commit the cleanup, and open a GitHub PR. | `--per-gem`, `--[no-]bundle`, `--comment` |
| `init` | Write a starter `.gemxray.yml`. | `--force` |
| `version` | Print the installed gemxray version. | none |
| `help` | Print top-level help. | none |

### Shared analysis options

`scan`, `clean`, and `pr` all build the same report first, so the options below change which findings are available to print, remove, or turn into pull requests.

- `--gemfile PATH`
  Selects the target Gemfile. This also changes the project root used for file edits, `bundle install`, and git operations, because the project root is derived from the Gemfile directory.
- `--config PATH`
  Loads a specific `.gemxray.yml` instead of the default file in the current working directory.
- `--only unused,redundant,version`
  Restricts analysis to the listed analyzers. This accepts a comma-separated list. For example, `--only unused` means `clean` and `pr` only act on unused-gem findings.
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

Typical examples:

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
- In a real edit, it writes a backup file at `Gemfile.bak` before saving changes.
- If nothing is selected, it prints `No removable gems were selected.` and exits with status `0`.

Command-specific options:

- `--auto-fix`
  Skips prompts and removes every reported `danger` finding automatically. `warning` and `info` findings are never auto-removed.
- `--dry-run`
  Does not write the Gemfile. Instead, it prints the selected candidates and a preview hunk showing the lines that would be removed or replaced.
- `--comment`
  Replaces each removed gem entry with a comment such as `# Removed by gemxray: ...` instead of deleting the lines outright.
- `--bundle`, `--no-bundle`
  After a real edit, `--bundle` runs `bundle install` in the target project. It is skipped automatically during `--dry-run` and when no gems were actually removed.

Typical examples:

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
- It tries `gh pr create` first. If that is unavailable, it falls back to the GitHub API when `GH_TOKEN` or `GITHUB_TOKEN` is set.
- The PR body includes removed gems, detection reasons, and a short checklist.

Command-specific options:

- `--per-gem`
  Creates one branch and one pull request per reported gem instead of grouping everything into a single cleanup PR.
- `--comment`
  Leaves comments in the Gemfile instead of deleting lines, using the same replacement behavior as `clean --comment`.
- `--bundle`, `--no-bundle`
  Controls whether `pr` runs `bundle install` before committing. The default is `--bundle`, which comes from `github.bundle_install: true`.

Typical examples:

```bash
bundle exec gemxray pr
bundle exec gemxray pr --per-gem --no-bundle
bundle exec gemxray pr --only unused --severity danger
```

### `init`

`init` writes a starter `.gemxray.yml` into the current working directory.

Behavior:

- It does not read `--config`; it always writes `.gemxray.yml` in the directory where you run the command.
- If the file already exists, the command fails unless you pass `--force`.

Command-specific options:

- `--force`
  Overwrites an existing `.gemxray.yml`.

Typical example:

```bash
bundle exec gemxray init --force
```

### `version`

`version` prints the installed gemxray version and exits with status `0`.

Typical example:

```bash
bundle exec gemxray version
```

### `help`

`help` prints the top-level command summary and exits with status `0`.

Typical examples:

```bash
bundle exec gemxray help
bundle exec gemxray --help
bundle exec gemxray scan --help
```

## Severity

- `danger`: high-confidence removal candidate. `clean --auto-fix` only removes `danger` findings.
- `warning`: likely removable, but worth a quick review.
- `info`: informative hint, often tied to pinned versions or lower-confidence redundancy.

## Configuration

`gemxray` reads `.gemxray.yml` from the working directory unless you pass `--config PATH`.

The effective config is built in this order:

1. built-in defaults
2. `.gemxray.yml`
3. CLI options for the current run

Later scalar values override earlier ones. Array values are merged and deduplicated, so list-like fields such as `scan_dirs`, `whitelist`, `github.labels`, and `github.reviewers` are additive.

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

### Top-level fields

- `version`
  Template default: `1`.
  This is currently a schema marker for humans and future compatibility. The current implementation accepts it but does not change behavior based on the value yet.
- `gemfile_path`
  Default: `Gemfile`.
  Path to the target Gemfile. This is usually passed via `--gemfile PATH`, but it can also live in the YAML file. The path is expanded from the current working directory, not from the directory that contains `.gemxray.yml`.
- `format`
  Default: `terminal`.
  Output format used by `scan`. Accepted values are `terminal`, `json`, and `yaml`.
- `only`
  Default: all analyzers.
  Restricts analysis to a subset of analyzers. Accepted values are `unused`, `redundant`, and `version`. This affects `scan`, `clean`, and `pr`, because all three commands build the same report first.
- `severity`
  Default: `info`.
  Minimum severity that remains in the report. `warning` keeps `danger` and `warning`. `danger` keeps only `danger`. This filtering happens before follow-up actions, so it also limits what `clean`, `pr`, and `scan --ci` can act on.
- `ci`
  Default: `false`.
  Enables CI-style exit codes for `scan`. When it is `true`, `scan` exits with status `1` if any reported result meets `ci_fail_on`.
- `ci_fail_on`
  Default: `warning`.
  Minimum reported severity that makes `scan --ci` fail. Accepted values are `info`, `warning`, and `danger`. This is evaluated after `severity` filtering, so a finding hidden by `severity` cannot fail CI.
- `auto_fix`
  Default: `false`.
  Used by `clean`. When `true`, `clean` removes every reported `danger` finding without prompting. It never auto-removes `warning` or `info` findings.
- `dry_run`
  Default: `false`.
  Used by `clean`. Generates a preview of the Gemfile changes without writing the file.
- `comment`
  Default: `false`.
  Used by `clean` and `pr`. When `true`, gem entries are replaced with comments instead of being deleted outright.
- `bundle_install`
  Default: `false`.
  Used by `clean`. Runs `bundle install` after a real Gemfile edit. This top-level field does not control `pr`; pull request creation uses `github.bundle_install`.
- `whitelist`
  Default: `[]`.
  List of gem names to skip completely. Whitelisted gems are ignored by the analyzers and never appear in the report.
- `scan_dirs`
  Default: `[]`.
  Extra directories to scan for `require` calls, constant references, and gemspec dependencies. These are added to the built-in scan roots: `app`, `lib`, `config`, `db`, `script`, `bin`, `exe`, `spec`, `test`, and `tasks`. Missing directories are ignored.
- `redundant_depth`
  Default: `2`.
  Maximum dependency depth used by the `redundant` analyzer when it looks for a parent gem in `Gemfile.lock`. Lower values make redundant detection more conservative.
- `overrides`
  Default: `{}`.
  Per-gem overrides keyed by gem name. This is the place to suppress a gem entirely or force its final severity.

### Override fields

- `overrides.<gem>.severity`
  Accepted values: `ignore`, `info`, `warning`, `danger`.
  `ignore` skips the gem before analysis, so no finding is produced for it. `info`, `warning`, and `danger` keep the finding but force the final reported severity for that gem after analyzer results are merged.

### GitHub fields

- `github.base_branch`
  Default: `main`.
  Base branch that `pr` checks out before it creates the cleanup branch.
- `github.labels`
  Default: `dependencies`, `cleanup`.
  Labels applied to created pull requests. Because arrays are merged, custom labels are added to the defaults instead of replacing them.
- `github.reviewers`
  Default: `[]`.
  Reviewers requested when `pr` opens a pull request.
- `github.per_gem`
  Default: `false`.
  When `true`, `pr` creates one branch and one pull request per gem. When `false`, it groups all selected gems into a single cleanup branch and PR.
- `github.bundle_install`
  Default: `true`.
  Controls whether `pr` runs `bundle install` before it commits changes.

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
