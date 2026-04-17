# frozen_string_literal: true

module GemXray
  module Analyzers
    class LicenseAnalyzer < Base
      def analyze(gems)
        allowed = config.license_allowed
        deny_unknown = config.license_deny_unknown?
        fetcher = LicenseFetcher.new
        matcher = LicenseMatcher.new

        gems.filter_map do |gem_entry|
          next if skipped?(gem_entry)

          info = fetcher.fetch(gem_entry.name, version: gem_entry.version)

          if info.licenses.empty?
            build_result(
              gem_entry: gem_entry,
              type: :license_unknown,
              severity: deny_unknown ? :danger : :warning,
              detail: "no license information found"
            )
          elsif allowed.any?
            violating = info.licenses.reject { |lic| matcher.match?(lic, allowed) }
            next if violating.empty?

            build_result(
              gem_entry: gem_entry,
              type: :license_violation,
              severity: :danger,
              detail: "license not in allowed list: #{violating.join(', ')}"
            )
          end
        end
      end
    end
  end
end
