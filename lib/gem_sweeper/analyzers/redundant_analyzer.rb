# frozen_string_literal: true

module GemSweeper
  module Analyzers
    class RedundantAnalyzer < Base
      def analyze(gems)
        gem_names = gems.map(&:name)

        gems.filter_map do |gem_entry|
          next if skipped?(gem_entry)

          path = dependency_resolver.find_parent(
            target: gem_entry.name,
            roots: gem_names - [gem_entry.name],
            max_depth: config.redundant_depth
          )
          next unless path

          detail = "already installed as a dependency of #{path.first}"
          detail = "#{detail} (#{path.join(' -> ')})" if path.length > 2

          build_result(
            gem_entry: gem_entry,
            type: :redundant,
            severity: gem_entry.pinned_version? ? :info : :warning,
            detail: detail
          )
        end
      end
    end
  end
end
