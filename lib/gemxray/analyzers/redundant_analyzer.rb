# frozen_string_literal: true

module GemXray
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
          next unless compatible_dependency?(gem_entry, path[:edges].last)

          detail = "already installed as a dependency of #{path[:gems].first}"
          detail = "#{detail} (#{path[:gems].join(' -> ')})" if path[:gems].length > 2

          build_result(
            gem_entry: gem_entry,
            type: :redundant,
            severity: gem_entry.pinned_version? ? :info : :warning,
            detail: detail
          )
        end
      end

      private

      def compatible_dependency?(gem_entry, edge)
        return true unless gem_entry.pinned_version?

        requirement = edge.requirement
        return true unless requirement

        pinned_requirement = Gem::Requirement.new(gem_entry.version)
        resolved_version = gemfile_parser.resolved_version(gem_entry.name)
        if resolved_version
          return pinned_requirement.satisfied_by?(resolved_version) && requirement.satisfied_by?(resolved_version)
        end

        allowed_versions = sample_versions_for(gem_entry.version)

        allowed_versions.any? do |version|
          pinned_requirement.satisfied_by?(version) && requirement.satisfied_by?(version)
        end
      rescue ArgumentError
        false
      end

      def sample_versions_for(requirement_string)
        versions = requirement_string.scan(/\d+(?:\.\d+)+/).map { |value| Gem::Version.new(value) }
        versions << Gem::Version.new(requirement_string[/\d+(?:\.\d+)+/] || "0")
        versions.uniq
      end
    end
  end
end
