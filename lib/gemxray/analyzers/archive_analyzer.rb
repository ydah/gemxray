# frozen_string_literal: true

module GemXray
  module Analyzers
    class ArchiveAnalyzer < Base
      def analyze(gems)
        token = config.archive_github_token
        overrides = config.archive.fetch(:overrides, {})
        finder = RepositoryFinder.new(overrides: overrides)
        checker = ArchiveChecker.new(token: token)

        gems.filter_map do |gem_entry|
          next if skipped?(gem_entry)

          owner_repo = finder.find(gem_entry.name)
          next unless owner_repo

          result = checker.check(owner_repo)
          next unless result.archived

          build_result(
            gem_entry: gem_entry,
            type: :archived,
            severity: :warning,
            detail: "source repository is archived: #{owner_repo}"
          )
        end
      end
    end
  end
end
