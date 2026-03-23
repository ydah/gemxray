# frozen_string_literal: true

module GemSweeper
  class Report
    attr_reader :version, :ruby_version, :rails_version, :scanned_at, :results

    def initialize(version:, ruby_version:, rails_version:, scanned_at:, results:)
      @version = version
      @ruby_version = ruby_version
      @rails_version = rails_version
      @scanned_at = scanned_at
      @results = results
    end

    def summary
      {
        total: results.length,
        danger: results.count { |result| result.severity == :danger },
        warning: results.count { |result| result.severity == :warning },
        info: results.count { |result| result.severity == :info }
      }
    end

    def to_h
      {
        version: version,
        ruby_version: ruby_version,
        rails_version: rails_version,
        scanned_at: scanned_at,
        results: results.map(&:to_h),
        summary: summary
      }
    end
  end
end
