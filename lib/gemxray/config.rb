# frozen_string_literal: true

require "yaml"

module GemXray
  class Config
    DEFAULT_CONFIG_PATH = ".gemxray.yml"
    DEFAULT_SCAN_DIRS = %w[app lib config db script bin exe spec test tasks].freeze
    DEFAULTS = {
      gemfile_path: "Gemfile",
      format: "terminal",
      only: nil,
      severity: "info",
      auto_fix: false,
      dry_run: false,
      ci: false,
      comment: false,
      bundle_install: false,
      whitelist: [],
      scan_dirs: [],
      overrides: {},
      redundant_depth: 2,
      github: {
        base_branch: "main",
        labels: %w[dependencies cleanup],
        reviewers: [],
        per_gem: false,
        bundle_install: true
      }
    }.freeze
    SEVERITY_ORDER = { danger: 0, warning: 1, info: 2 }.freeze
    TEMPLATE = <<~YAML.freeze
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
        bundle_install: true
    YAML

    attr_reader :config_path, :gemfile_path, :format, :only, :severity_threshold, :whitelist,
                :scan_dirs, :overrides, :redundant_depth, :github

    def self.load(options = {})
      raw_options = symbolize_keys(options)
      config_path = raw_options.delete(:config_path) || DEFAULT_CONFIG_PATH
      file_options = load_file_config(config_path)
      merged = deep_merge(DEFAULTS, deep_merge(file_options, raw_options))

      new(merged, config_path: config_path)
    end

    def self.load_file_config(path)
      return {} unless path && File.exist?(path)

      symbolize_keys(YAML.safe_load(File.read(path), aliases: true) || {})
    end

    def self.symbolize_keys(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, nested), result|
          result[key.to_sym] = symbolize_keys(nested)
        end
      when Array
        value.map { |item| symbolize_keys(item) }
      else
        value
      end
    end

    def self.deep_merge(left, right)
      left.merge(right) do |_key, left_value, right_value|
        if left_value.is_a?(Hash) && right_value.is_a?(Hash)
          deep_merge(left_value, right_value)
        elsif left_value.is_a?(Array) && right_value.is_a?(Array)
          (left_value + right_value).uniq
        else
          right_value
        end
      end
    end

    def initialize(options, config_path:)
      @config_path = config_path
      @gemfile_path = File.expand_path(options.fetch(:gemfile_path))
      @format = options.fetch(:format).to_s
      @only = normalize_only(options[:only])
      @severity_threshold = normalize_severity(options.fetch(:severity))
      @whitelist = Array(options[:whitelist]).map(&:to_s).uniq
      @scan_dirs = (DEFAULT_SCAN_DIRS + Array(options[:scan_dirs]).map(&:to_s)).uniq
      @overrides = options.fetch(:overrides, {})
      @redundant_depth = options.fetch(:redundant_depth).to_i
      @github = options.fetch(:github)
      @auto_fix = truthy?(options[:auto_fix])
      @dry_run = truthy?(options[:dry_run])
      @ci = truthy?(options[:ci])
      @comment = truthy?(options[:comment])
      @bundle_install = truthy?(options[:bundle_install])
    end

    def lockfile_path
      "#{gemfile_path}.lock"
    end

    def project_root
      File.dirname(gemfile_path)
    end

    def auto_fix?
      @auto_fix
    end

    def dry_run?
      @dry_run
    end

    def ci?
      @ci
    end

    def comment?
      @comment
    end

    def bundle_install?
      @bundle_install
    end

    def whitelisted?(gem_name)
      whitelist.include?(gem_name.to_s)
    end

    def override_for(gem_name)
      overrides[gem_name.to_sym] || overrides[gem_name.to_s]
    end

    def ignore_gem?(gem_name)
      override = override_for(gem_name)
      override && override[:severity].to_s == "ignore"
    end

    def override_severity_for(gem_name)
      override = override_for(gem_name)
      severity = override && override[:severity]
      return nil if severity.nil? || severity.to_s == "ignore"

      normalize_severity(severity)
    end

    def severity_in_scope?(severity)
      SEVERITY_ORDER.fetch(severity) <= SEVERITY_ORDER.fetch(severity_threshold)
    end

    def github_base_branch
      github.fetch(:base_branch, "main")
    end

    def github_labels
      Array(github.fetch(:labels, []))
    end

    def github_reviewers
      Array(github.fetch(:reviewers, []))
    end

    def github_per_gem?
      truthy?(github.fetch(:per_gem, false))
    end

    def github_bundle_install?
      truthy?(github.fetch(:bundle_install, true))
    end

    private

    def normalize_only(value)
      items =
        case value
        when nil then nil
        when String then value.split(",")
        else Array(value)
        end

      items&.map { |item| item.to_s.strip }&.reject(&:empty?)&.map(&:to_sym)
    end

    def normalize_severity(value)
      key = value.to_s.strip.downcase.to_sym
      return key if SEVERITY_ORDER.key?(key)

      raise Error, "unknown severity: #{value}"
    end

    def truthy?(value)
      value == true || value.to_s == "true"
    end
  end
end
