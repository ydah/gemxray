# frozen_string_literal: true

module GemXray
  module Analyzers
    class SecurityAnalyzer < Base
      def analyze(gems)
        fetcher = SecurityAdvisoryFetcher.new(
          advisory_db_path: config.security_advisory_db_path,
          cache_ttl: config.security_cache_ttl,
          github_token: config.security_github_token
        )
        locked_versions = gemfile_parser.locked_versions

        security_entries(gems, locked_versions).filter_map do |gem_entry|
          next if skipped?(gem_entry)

          version = exact_version(gem_entry.version)
          next unless version

          advisories = fetcher.fetch(gem_entry.name).select { |advisory| advisory.vulnerable?(version) }
          next if advisories.empty?

          build_security_result(gem_entry, version, advisories)
        end
      end

      private

      def security_entries(gems, locked_versions)
        return gems if locked_versions.empty?

        direct_entries = gems.each_with_object({}) { |gem_entry, index| index[gem_entry.name] = gem_entry }
        locked_versions.map do |name, version|
          direct_entry = direct_entries[name]
          direct_entry ? entry_with_locked_version(direct_entry, version) : GemEntry.new(name: name, version: version.to_s)
        end
      end

      def entry_with_locked_version(gem_entry, version)
        GemEntry.new(
          name: gem_entry.name,
          version: version.to_s,
          groups: gem_entry.groups,
          line_number: gem_entry.line_number,
          end_line: gem_entry.end_line,
          source_line: gem_entry.source_line,
          autorequire: gem_entry.autorequire,
          options: gem_entry.options
        )
      end

      def exact_version(value)
        requirement = Gem::Requirement.new(value.to_s)
        return unless requirement.requirements.one?

        operator, version = requirement.requirements.first
        version if operator == "="
      rescue ArgumentError, Gem::Requirement::BadRequirementError
        nil
      end

      def build_security_result(gem_entry, version, advisories)
        first, *rest = advisories
        result = build_result(
          gem_entry: gem_entry,
          type: :security_vulnerability,
          severity: :danger,
          detail: detail_for(gem_entry, version, first),
          suggestion: suggestion_for(gem_entry, advisories)
        )

        rest.each do |advisory|
          result.add_reason(
            type: :security_vulnerability,
            severity: :danger,
            detail: detail_for(gem_entry, version, advisory)
          )
        end

        result
      end

      def detail_for(gem_entry, version, advisory)
        title = advisory.title.to_s.empty? ? "" : " (#{advisory.title})"
        "#{gem_entry.name} #{version} is affected by #{advisory.identifier}#{title}; patched versions: #{advisory.patched_versions_text}"
      end

      def suggestion_for(gem_entry, advisories)
        patched_versions = advisories.flat_map(&:patched_versions).uniq
        patched_hint = patched_versions.empty? ? "" : " (#{patched_versions.join(', ')})"
        "Update #{gem_entry.name} to a patched version#{patched_hint} or update the dependency that brings it in"
      end
    end
  end
end
