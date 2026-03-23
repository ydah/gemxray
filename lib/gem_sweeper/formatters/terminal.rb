# frozen_string_literal: true

module GemSweeper
  module Formatters
    class Terminal
      def render(report)
        lines = ["gem-sweeper scan results", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", ""]

        if report.results.empty?
          lines << "問題は見つかりませんでした。"
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
        lines << "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        lines << "検出: #{summary[:total]}件 (DANGER: #{summary[:danger]}, WARNING: #{summary[:warning]}, INFO: #{summary[:info]})"
        lines.join("\n")
      end
    end
  end
end
