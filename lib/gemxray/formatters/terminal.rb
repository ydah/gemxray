# frozen_string_literal: true

module GemXray
  module Formatters
    class Terminal
      HEADER = "🧹 gemxray scan results"
      SEPARATOR = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      def render(report)
        lines = [HEADER, SEPARATOR, ""]

        if report.results.empty?
          lines << "No issues found."
        else
          report.results.each do |result|
            lines << "[#{result.severity.to_s.upcase}] #{result.gem_name} (#{result.type_label})"
            result.reasons.each_with_index do |reason, index|
              marker = index == result.reasons.length - 1 ? "└─" : "├─"
              lines << "  #{marker} #{reason.detail}"
            end
            lines << ""
          end
        end

        summary = report.summary
        lines << SEPARATOR
        lines << "検出: #{summary[:total]}件 (DANGER: #{summary[:danger]}, WARNING: #{summary[:warning]}, INFO: #{summary[:info]})"
        lines.join("\n")
      end
    end
  end
end
