# frozen_string_literal: true

require "optparse"

module GemXray
  class CLI
    HelpRequested = Class.new(StandardError)
    COMMANDS = %w[scan clean pr init version help].freeze

    def self.start(argv = ARGV, out: $stdout, err: $stderr, stdin: $stdin)
      new(argv, out: out, err: err, stdin: stdin).run
    end

    def initialize(argv, out:, err:, stdin:)
      @argv = argv.dup
      @out = out
      @err = err
      @stdin = stdin
    end

    def run
      command = extract_command

      case command
      when "scan" then run_scan(@argv)
      when "clean" then run_clean(@argv)
      when "pr" then run_pr(@argv)
      when "init" then run_init(@argv)
      when "version"
        out.puts(GemXray::VERSION)
        0
      else
        out.puts(help_text)
        0
      end
    rescue HelpRequested
      0
    rescue OptionParser::ParseError => e
      err.puts(e.message)
      err.puts(help_text)
      1
    rescue Error => e
      err.puts("Error: #{e.message}")
      1
    end

    private

    attr_reader :out, :err, :stdin

    def extract_command
      return "scan" if @argv.empty?
      return "help" if %w[-h --help].include?(@argv.first)
      return "scan" if @argv.first.start_with?("-")

      return @argv.shift if COMMANDS.include?(@argv.first)

      "scan"
    end

    def run_scan(argv)
      config = Config.load(parse_scan_options(argv))
      report = Scanner.new(config).run
      out.puts(formatter_for(config.format).render(report))
      config.ci? && report.results.any? ? 1 : 0
    end

    def run_clean(argv)
      options = parse_clean_options(argv)
      config = Config.load(options)
      report = Scanner.new(config).run
      candidates = config.auto_fix? ? report.results.select(&:danger?) : interactive_selection(report.results)

      if candidates.empty?
        out.puts("No removable gems were selected.")
        return 0
      end

      editor = Editors::GemfileEditor.new(config.gemfile_path)
      outcome = editor.apply(candidates, dry_run: config.dry_run?, comment: config.comment?, backup: true)
      out.puts("Candidates: #{candidates.map(&:gem_name).join(', ')}")
      out.puts(outcome.preview) if config.dry_run? && !outcome.preview.to_s.empty?
      out.puts("Removed: #{outcome.removed.join(', ')}") unless outcome.removed.empty?
      out.puts("Skipped: #{outcome.skipped.join(', ')}") unless outcome.skipped.empty?
      if config.bundle_install? && !config.dry_run? && outcome.removed.any?
        out.puts(editor.bundle_install!)
      end
      0
    end

    def run_pr(argv)
      options = parse_pr_options(argv)
      config = Config.load(options)
      report = Scanner.new(config).run
      raise Error, "no PR candidates were found" if report.results.empty?

      result = Editors::GithubPr.new(config).create(
        report.results,
        per_gem: options.fetch(:per_gem, config.github_per_gem?),
        bundle_install: options.fetch(:bundle_install, config.github_bundle_install?),
        comment: config.comment?
      )

      pull_requests = Array(result[:pull_requests])
      if pull_requests.length <= 1
        out.puts("Branch: #{result[:branch]}")
        out.puts("PR: #{result[:pr_url]}")
      else
        out.puts("Created #{pull_requests.length} PRs:")
        pull_requests.each do |pull_request|
          label = pull_request[:gem_name] || Array(pull_request[:gem_names]).join(", ")
          out.puts("#{label}: #{pull_request[:pr_url]} (#{pull_request[:branch]})")
        end
      end
      0
    end

    def run_init(argv)
      options = { force: false }
      OptionParser.new do |parser|
        parser.banner = "Usage: gemxray init [--force]"
        parser.on("--force", "overwrite an existing config file") { options[:force] = true }
        parser.on("-h", "--help", "show help") do
          out.puts(parser)
          raise HelpRequested
        end
      end.parse!(argv)

      path = File.expand_path(Config::DEFAULT_CONFIG_PATH)
      if File.exist?(path) && !options[:force]
        raise Error, "#{Config::DEFAULT_CONFIG_PATH} already exists"
      end

      File.write(path, Config::TEMPLATE)
      out.puts("created #{Config::DEFAULT_CONFIG_PATH}")
      0
    end

    def parse_scan_options(argv)
      options = {}

      OptionParser.new do |parser|
        parser.banner = "Usage: gemxray scan [options]"
        common_options(parser, options)
      end.parse!(argv)

      options
    end

    def parse_clean_options(argv)
      options = {}

      OptionParser.new do |parser|
        parser.banner = "Usage: gemxray clean [options]"
        common_options(parser, options)
        parser.on("--auto-fix", "remove only danger level gems without prompting") { options[:auto_fix] = true }
        parser.on("--dry-run", "show targets without writing Gemfile") { options[:dry_run] = true }
        parser.on("--comment", "leave a comment in place of the removed gem line") { options[:comment] = true }
        parser.on("--[no-]bundle", "run bundle install after editing") { |value| options[:bundle_install] = value }
      end.parse!(argv)

      options
    end

    def parse_pr_options(argv)
      options = {}

      OptionParser.new do |parser|
        parser.banner = "Usage: gemxray pr [options]"
        common_options(parser, options)
        parser.on("--[no-]bundle", "run bundle install before committing (default: yes)") do |value|
          options[:bundle_install] = value
        end
        parser.on("--comment", "leave comments in Gemfile instead of deleting lines") { options[:comment] = true }
        parser.on("--per-gem", "create one PR per gem") { options[:per_gem] = true }
      end.parse!(argv)

      options
    end

    def common_options(parser, options)
      parser.on("-f", "--format FORMAT", %w[terminal json yaml], "output format") { |value| options[:format] = value }
      parser.on("-g", "--gemfile PATH", "path to Gemfile") { |value| options[:gemfile_path] = value }
      parser.on("--only LIST", "comma separated analyzers (unused,redundant,version)") do |value|
        options[:only] = value.split(",")
      end
      parser.on("--severity LEVEL", %w[info warning danger], "minimum severity to report") do |value|
        options[:severity] = value
      end
      parser.on("--ci", "exit with status 1 when issues are found") { options[:ci] = true }
      parser.on("--config PATH", "path to .gemxray.yml") { |value| options[:config_path] = value }
      parser.on("-h", "--help", "show help") do
        out.puts(parser)
        raise HelpRequested
      end
    end

    def formatter_for(format)
      case format
      when "terminal" then Formatters::Terminal.new
      when "json" then Formatters::Json.new
      when "yaml" then Formatters::Yaml.new
      else
        raise Error, "unknown format: #{format}"
      end
    end

    def interactive_selection(results)
      results.filter_map do |result|
        out.print("Remove #{result.gem_name} (#{result.severity})? [y/N]: ")
        answer = stdin.gets.to_s.strip.downcase
        result if answer == "y" || answer == "yes"
      end
    end

    def help_text
      <<~TEXT
        gemxray [COMMAND] [OPTIONS]

        Commands:
          scan     Analyze Gemfile and report removable gems
          clean    Interactively remove reported gems from Gemfile
          pr       Create a cleanup branch, commit, and open a GitHub PR
          init     Generate .gemxray.yml
          version  Print gemxray version
      TEXT
    end
  end
end
