# frozen_string_literal: true

module GemXray
  module Formatters
    class Terminal
      def render(report)
        lines = ["gemxray scan results", "-----------------------------------------------------------------", ""]

        if report.results.empty?
          lines << "No issues found."
        else
          report.results.each do |result|
            lines << "[#{result.severity.to_s.upcase}] #{result.gem_name} (#{result.type_label})"
            result.reasons.each do |reason|
              lines << "  - #{reason.detail}"
            end
            lines << ""
          end
        end

        summary = report.summary
        lines << "-----------------------------------------------------------------"
        lines << "Found: #{summary[:total]} (DANGER: #{summary[:danger]}, WARNING: #{summary[:warning]}, INFO: #{summary[:info]})"
        lines.join("\n")
      end
    end
  end
end
