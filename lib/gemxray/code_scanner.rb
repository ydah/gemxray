# frozen_string_literal: true

require "find"
require "set"

module GemXray
  class CodeScanner
    SCAN_EXTENSIONS = %w[.rb .erb .haml .slim .rake .thor .gemspec .ru].freeze
    REQUIRE_PATTERN = /
      (?:
        \brequire(?:_relative)?\s*\(?\s*["']([^"']+)["']
      |
        send\(\s*:require\s*,\s*["']([^"']+)["']
      )
    /x.freeze
    CONSTANT_PATTERN = /\b(?:[A-Z][A-Za-z0-9]*)(?:::[A-Z][A-Za-z0-9]*)*\b/.freeze
    GEMSPEC_DEPENDENCY_PATTERN = /\badd_(?:runtime_)?dependency\s+["']([^"']+)["']/.freeze

    class Snapshot
      attr_reader :requires, :constants, :dependency_names, :files

      def initialize(requires:, constants:, dependency_names:, files:)
        @requires = requires
        @constants = constants
        @dependency_names = dependency_names
        @files = files
      end

      def require_used?(candidates)
        Array(candidates).any? do |candidate|
          requires.any? { |reference| reference == candidate || reference.start_with?("#{candidate}/") }
        end
      end

      def constant_used?(candidates)
        !(constants & candidates.to_set).empty?
      end

      def dependency_used?(gem_name)
        dependency_names.include?(gem_name)
      end
    end

    def initialize(config)
      @config = config
    end

    def scan
      requires = Set.new
      constants = Set.new
      dependency_names = Set.new
      files = scan_files

      files.each do |path|
        content = File.read(path, encoding: "utf-8")
        extract_requires(content).each { |value| requires << value }
        content.scan(CONSTANT_PATTERN).each { |value| constants << value }
        content.scan(GEMSPEC_DEPENDENCY_PATTERN).flatten.each { |value| dependency_names << value }
      rescue ArgumentError, Errno::ENOENT
        next
      end

      Snapshot.new(
        requires: requires,
        constants: constants,
        dependency_names: dependency_names,
        files: files
      )
    end

    private

    attr_reader :config

    def scan_files
      root = config.project_root
      paths = []

      config.scan_dirs.each do |relative_dir|
        absolute_dir = File.join(root, relative_dir)
        next unless Dir.exist?(absolute_dir)

        Find.find(absolute_dir) do |path|
          next if File.directory?(path)
          next unless SCAN_EXTENSIONS.include?(File.extname(path))

          paths << path
        end
      end

      %w[Gemfile Rakefile].each do |filename|
        absolute_path = File.join(root, filename)
        paths << absolute_path if File.exist?(absolute_path)
      end

      Dir.glob(File.join(root, "*.gemspec")).each { |path| paths << path }

      paths.uniq
    end

    def extract_requires(content)
      content.scan(REQUIRE_PATTERN).map { |left, right| left || right }.compact
    end
  end
end
