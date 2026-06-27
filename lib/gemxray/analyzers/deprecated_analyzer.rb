# frozen_string_literal: true

module GemXray
  module Analyzers
    class DeprecatedAnalyzer < Base
      def analyze(gems)
        fetcher = DeprecatedGemFetcher.new(check_readme: config.deprecated_check_readme?)

        gems.filter_map do |gem_entry|
          next if skipped?(gem_entry)

          info = fetcher.fetch(gem_entry.name, version: resolved_version_for(gem_entry))
          next unless info.deprecated?

          build_deprecated_result(gem_entry, info)
        end
      end

      private

      def resolved_version_for(gem_entry)
        gemfile_parser.resolved_version(gem_entry.name) || exact_version(gem_entry.version)
      end

      def exact_version(value)
        requirement = Gem::Requirement.new(value.to_s)
        return unless requirement.requirements.one?

        operator, version = requirement.requirements.first
        version if operator == "="
      rescue ArgumentError, Gem::Requirement::BadRequirementError
        nil
      end

      def build_deprecated_result(gem_entry, info)
        first, *rest = reasons_for(gem_entry, info)
        result = build_result(
          gem_entry: gem_entry,
          type: first.fetch(:type),
          severity: first.fetch(:severity),
          detail: first.fetch(:detail),
          suggestion: "Review #{gem_entry.name} and replace it with a maintained alternative"
        )

        rest.each do |reason|
          result.add_reason(
            type: reason.fetch(:type),
            severity: reason.fetch(:severity),
            detail: reason.fetch(:detail)
          )
        end

        result
      end

      def reasons_for(gem_entry, info)
        reasons = []
        version = info.version || resolved_version_for(gem_entry) || "unknown version"

        if info.yanked
          reasons << {
            type: :deprecated_yanked,
            severity: :danger,
            detail: "#{gem_entry.name} #{version} has been yanked from RubyGems"
          }
        end

        if info.post_install_deprecated?
          reasons << {
            type: :deprecated_post_install_message,
            severity: :warning,
            detail: "post_install_message marks #{gem_entry.name} as deprecated"
          }
        end

        if info.readme_deprecated
          source = info.readme_url ? ": #{info.readme_url}" : ""
          reasons << {
            type: :deprecated_readme,
            severity: :warning,
            detail: "README says \"This gem is deprecated\"#{source}"
          }
        end

        reasons
      end
    end
  end
end
