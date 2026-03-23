# frozen_string_literal: true

module GemSweeper
  module Analyzers
    class VersionAnalyzer < Base
      def analyze(gems)
        ruby_version = gemfile_parser.ruby_version
        rails_version = gemfile_parser.rails_version(gems)
        default_gems = stdgems_client.default_gems_for(ruby_version)

        gems.each_with_object([]) do |gem_entry, results|
          next if skipped?(gem_entry)

          if default_gems.include?(gem_entry.name) && !gem_entry.pinned_version?
            results << build_result(
              gem_entry: gem_entry,
              type: :version_redundant,
              severity: :warning,
              detail: "Ruby #{ruby_version} already ships this as a default gem"
            )
          end

          change = rails_knowledge.find_removal(gem_entry.name, rails_version)
          next unless change

          results << build_result(
            gem_entry: gem_entry,
            type: :version_redundant,
            severity: :warning,
            detail: "since Rails #{change.since}, #{change.reason}"
          )
        end
      end
    end
  end
end
