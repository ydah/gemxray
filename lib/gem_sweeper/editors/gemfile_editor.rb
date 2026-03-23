# frozen_string_literal: true

require "open3"

module GemSweeper
  module Editors
    class GemfileEditor
      EditResult = Struct.new(:removed, :skipped, :dry_run, :backup_path, keyword_init: true)

      def initialize(gemfile_path)
        @gemfile_path = File.expand_path(gemfile_path)
      end

      def apply(results, dry_run:, comment:, backup: true)
        lines = File.readlines(gemfile_path, chomp: false)
        removed = []
        skipped = []

        results.sort_by { |result| -(result.gemfile_line || 0) }.each do |result|
          line_number = result.gemfile_line
          if !line_number || !gem_line?(lines[line_number - 1], result.gem_name)
            skipped << result.gem_name
            next
          end

          if comment
            lines[line_number - 1] = "# Removed by gem-sweeper: #{result.gem_name} (#{result.type_label})\n"
          else
            lines.delete_at(line_number - 1)
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

        EditResult.new(removed: removed.reverse, skipped: skipped.uniq, dry_run: dry_run, backup_path: backup_path)
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

      def project_root
        File.dirname(gemfile_path)
      end
    end
  end
end
