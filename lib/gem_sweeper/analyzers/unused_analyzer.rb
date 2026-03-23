# frozen_string_literal: true

module GemSweeper
  module Analyzers
    class UnusedAnalyzer < Base
      KNOWN_DEV_TOOLS = %w[
        brakeman bundler-audit byebug capistrano capistrano-rails codecov
        debug factory_bot factory_bot_rails faker overcommit pry pry-rails
        rake rspec rspec-core rspec-rails rubocop rubocop-performance
        rubocop-rails rubocop-rspec simplecov
      ].freeze

      def analyze(gems)
        gems.filter_map do |gem_entry|
          next if skipped?(gem_entry)
          next if KNOWN_DEV_TOOLS.include?(gem_entry.name)
          next if gem_used?(gem_entry)

          detail =
            if gem_entry.development_group?
              "コード内で未使用（group :development / :test）"
            else
              "コード内に require および定数参照が見つからない"
            end

          build_result(
            gem_entry: gem_entry,
            type: :unused,
            severity: gem_entry.development_group? ? :warning : :danger,
            detail: detail
          )
        end
      end

      private

      def gem_used?(gem_entry)
        code_snapshot.require_used?(require_candidates(gem_entry)) ||
          code_snapshot.constant_used?(constant_candidates(gem_entry.name)) ||
          code_snapshot.dependency_used?(gem_entry.name) ||
          autoloaded_gem?(gem_entry)
      end
    end
  end
end
