# frozen_string_literal: true

module GemSweeper
  module Analyzers
    class Base
      AUTOLOADED_GEMS = %w[
        bootsnap devise sidekiq sidekiq-cron delayed_job_active_record good_job
        letter_opener_web rack-mini-profiler spring sprockets-rails turbo-rails
        stimulus-rails importmap-rails propshaft web-console solid_queue
        solid_cache solid_cable
      ].freeze

      def initialize(config:, gemfile_parser:, code_snapshot: nil, dependency_resolver: nil, stdgems_client: nil,
                     rails_knowledge: nil)
        @config = config
        @gemfile_parser = gemfile_parser
        @code_snapshot = code_snapshot
        @dependency_resolver = dependency_resolver
        @stdgems_client = stdgems_client
        @rails_knowledge = rails_knowledge
      end

      private

      attr_reader :config, :gemfile_parser, :code_snapshot, :dependency_resolver, :stdgems_client, :rails_knowledge

      def skipped?(gem_entry)
        config.whitelisted?(gem_entry.name) || config.ignore_gem?(gem_entry.name)
      end

      def build_result(gem_entry:, type:, severity:, detail:)
        Result.new(
          gem_name: gem_entry.name,
          gemfile_line: gem_entry.line_number,
          gemfile_group: gem_entry.gemfile_group,
          reasons: [Result::Reason.new(type: type, detail: detail, severity: severity)],
          severity: severity
        )
      end

      def require_candidates(gem_entry)
        gem_entry.require_names.uniq
      end

      def constant_candidates(gem_name)
        parts = gem_name.split(%r{[/_-]}).reject(&:empty?)
        return [] if parts.empty?

        camelized = parts.map { |part| camelize(part) }
        [camelized.join, camelized.join("::")].uniq
      end

      def autoloaded_gem?(gem_entry)
        return true if AUTOLOADED_GEMS.include?(gem_entry.name)

        gem_has_railtie?(gem_entry.name)
      end

      def gem_has_railtie?(gem_name)
        @railtie_cache ||= {}
        return @railtie_cache[gem_name] if @railtie_cache.key?(gem_name)

        @railtie_cache[gem_name] = Gem::Specification.find_all_by_name(gem_name).any? do |spec|
          spec.require_paths.any? do |directory|
            Dir.glob(File.join(spec.full_gem_path, directory, "**/*.rb")).any? do |file|
              File.read(file, encoding: "utf-8").match?(/Rails::(?:Railtie|Engine)/)
            rescue StandardError
              false
            end
          end
        end
      rescue StandardError
        @railtie_cache[gem_name] = false
      end

      def camelize(value)
        value.split("_").map { |part| part[0]&.upcase.to_s + part[1..] }.join
      end
    end
  end
end
