# frozen_string_literal: true

module GemXray
  module Analyzers
    class UnmaintainedAnalyzer < Base
      def analyze(gems)
        finder = RepositoryFinder.new(overrides: config.unmaintained_overrides)
        checker = UnmaintainedChecker.new(token: config.unmaintained_github_token)
        threshold = Time.now - config.unmaintained_threshold_days * 86_400

        gems.filter_map do |gem_entry|
          next if skipped?(gem_entry)

          owner_repo = finder.find(gem_entry.name)
          next unless owner_repo

          activity = checker.check(owner_repo)
          next if activity.error
          next unless activity.unmaintained?(threshold)

          build_result(
            gem_entry: gem_entry,
            type: :unmaintained,
            severity: :warning,
            detail: detail_for(owner_repo, activity, config.unmaintained_threshold_days),
            suggestion: "Review #{gem_entry.name} and consider a maintained alternative"
          )
        end
      end

      private

      def detail_for(owner_repo, activity, threshold_days)
        last_activity = activity.last_activity_at&.strftime("%Y-%m-%d") || "unknown"
        years = (threshold_days / 365.0).round(1)
        "source repository appears unmaintained: #{owner_repo} last activity was #{last_activity} (threshold: #{years} years)"
      end
    end
  end
end
