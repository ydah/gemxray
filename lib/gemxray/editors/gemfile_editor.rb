# frozen_string_literal: true

require "open3"

module GemXray
  module Editors
    class GemfileEditor
      EditResult = Struct.new(:removed, :skipped, :dry_run, :backup_path, :preview, keyword_init: true)

      def initialize(gemfile_path)
        @gemfile_path = File.expand_path(gemfile_path)
      end

      def apply(results, dry_run:, comment:, backup: true)
        lines = File.readlines(gemfile_path, chomp: false)
        preview_hunks = []
        removed = []
        skipped = []

        results.sort_by { |result| -(result.gemfile_line || 0) }.each do |result|
          line_number = result.gemfile_line
          end_line = result.gemfile_end_line || line_number
          if !line_number || !gem_line?(lines[line_number - 1], result.gem_name)
            skipped << result.gem_name
            next
          end

          replacement =
            if comment
              ["#{leading_whitespace(lines[line_number - 1])}# Removed by gemxray: #{comment_summary(result)}\n"]
            else
              []
            end
          original = lines[(line_number - 1)..(end_line - 1)]
          preview_hunks << build_preview_hunk(result, original, replacement)

          if comment
            lines[(line_number - 1)..(end_line - 1)] = replacement
          else
            lines[(line_number - 1)..(end_line - 1)] = replacement
          end

          removed << result.gem_name
        end

        backup_path = nil
        unless dry_run || removed.empty?
          if backup
            backup_path = "#{gemfile_path}.bak"
            File.write(backup_path, File.read(gemfile_path))
          end
          File.write(gemfile_path, lines.join)
        end

        EditResult.new(
          removed: removed.reverse,
          skipped: skipped.uniq,
          dry_run: dry_run,
          backup_path: backup_path,
          preview: preview_hunks.reverse.join("\n")
        )
      end

      def bundle_install!
        stdout, stderr, status = Open3.capture3("bundle", "install", chdir: project_root)
        return stdout if status.success?

        raise Error, "bundle install failed: #{stderr.strip.empty? ? stdout.strip : stderr.strip}"
      end

      private

      attr_reader :gemfile_path

      def gem_line?(line, gem_name)
        line && line.match?(/^\s*gem\s+["']#{Regexp.escape(gem_name)}["']/)
      end

      def comment_summary(result)
        "#{result.gem_name} - #{result.reasons.map(&:detail).join(' / ')}"
      end

      def build_preview_hunk(result, original_lines, replacement_lines)
        header = "@@ #{File.basename(gemfile_path)}:#{result.gemfile_line}-#{result.gemfile_end_line || result.gemfile_line} #{result.gem_name} @@"
        removed = Array(original_lines).map { |line| "-#{line.chomp}" }
        added = Array(replacement_lines).map { |line| "+#{line.chomp}" }
        ([header] + removed + added).join("\n")
      end

      def leading_whitespace(line)
        line[/\A\s*/] || ""
      end

      def project_root
        File.dirname(gemfile_path)
      end
    end
  end
end
