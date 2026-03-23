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
                     rails_knowledge: nil, gem_metadata_resolver: GemMetadataResolver.new)
        @config = config
        @gemfile_parser = gemfile_parser
        @code_snapshot = code_snapshot
        @dependency_resolver = dependency_resolver
        @stdgems_client = stdgems_client
        @rails_knowledge = rails_knowledge
        @gem_metadata_resolver = gem_metadata_resolver
      end

      private

      attr_reader :config, :gemfile_parser, :code_snapshot, :dependency_resolver, :stdgems_client, :rails_knowledge,
                  :gem_metadata_resolver

      def skipped?(gem_entry)
        config.whitelisted?(gem_entry.name) || config.ignore_gem?(gem_entry.name)
      end

      def build_result(gem_entry:, type:, severity:, detail:)
        Result.new(
          gem_name: gem_entry.name,
          gemfile_line: gem_entry.line_number,
          gemfile_end_line: gem_entry.end_line,
          gemfile_group: gem_entry.gemfile_group,
          reasons: [Result::Reason.new(type: type, detail: detail, severity: severity)],
          severity: severity
        )
      end

      def require_candidates(gem_entry)
        gem_entry.require_names.uniq
      end

      def constant_candidates(gem_name)
        gem_metadata_resolver.constant_candidates_for(gem_name)
      end

      def autoloaded_gem?(gem_entry)
        return true if AUTOLOADED_GEMS.include?(gem_entry.name)

        gem_metadata_resolver.railtie?(gem_entry.name)
      end
    end
  end
end
