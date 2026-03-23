# frozen_string_literal: true

require "bundler"

module GemSweeper
  class GemfileParser
    attr_reader :gemfile_path, :lockfile_path

    def initialize(gemfile_path)
      @gemfile_path = File.expand_path(gemfile_path)
      @lockfile_path = "#{@gemfile_path}.lock"
    end

    def parse
      @parse ||= begin
        dependencies = bundler_dependencies
        metadata = declaration_metadata

        if dependencies.empty?
          parse_with_regex(metadata)
        else
          dependencies.map do |dependency|
            build_entry_from_dependency(dependency, metadata)
          end
        end
      end
    end

    def dependency_tree
      parser = lockfile_parser
      return {} unless parser

      parser.specs.each_with_object({}) do |spec, tree|
        tree[spec.name] = spec.dependencies.map(&:name)
      end
    end

    def ruby_version
      parser = lockfile_parser
      return RUBY_VERSION unless parser && parser.respond_to?(:ruby_version) && parser.ruby_version

      text = parser.ruby_version.to_s
      text[/\d+\.\d+(?:\.\d+)?/] || RUBY_VERSION
    end

    def rails_version(entries = parse)
      parser = lockfile_parser
      if parser
        rails_spec = parser.specs.find { |spec| spec.name == "rails" }
        return rails_spec.version.to_s if rails_spec
      end

      dependency = entries.find { |entry| entry.name == "rails" || entry.name == "railties" }
      return nil unless dependency

      dependency.version.to_s[/\d+\.\d+(?:\.\d+)?/]
    end

    private

    def bundler_dependencies
      Bundler::Dsl.evaluate(gemfile_path, nil, {}).dependencies
    rescue StandardError
      []
    end

    def build_entry_from_dependency(dependency, metadata)
      declaration = metadata.fetch(dependency.name, []).shift || {}
      GemEntry.new(
        name: dependency.name,
        version: normalized_requirement(dependency.requirement),
        groups: dependency.groups,
        line_number: declaration[:line_number],
        source_line: declaration[:source_line],
        autorequire: dependency.autorequire
      )
    end

    def normalized_requirement(requirement)
      return nil unless requirement

      text = Array(requirement.as_list).join(", ").strip
      text.empty? || text == ">= 0" ? nil : text
    end

    def declaration_metadata
      return {} unless File.exist?(gemfile_path)

      File.readlines(gemfile_path, chomp: true).each_with_index.with_object(Hash.new { |hash, key| hash[key] = [] }) do |(line, index), hash|
        match = line.match(/^\s*gem\s+["']([^"']+)["']/)
        next unless match

        hash[match[1]] << { line_number: index + 1, source_line: line }
      end
    end

    def parse_with_regex(metadata)
      groups = []
      entries = []

      File.readlines(gemfile_path, chomp: true).each_with_index do |line, index|
        stripped = line.sub(/\s+#.*$/, "").strip
        next if stripped.empty?

        if (group_match = stripped.match(/^group\s+\(?(.+?)\)?\s+do$/))
          groups << group_match[1].split(",").map { |item| item.delete(": ").to_sym }
          next
        end

        if stripped == "end"
          groups.pop
          next
        end

        gem_match = stripped.match(/^gem\s+["']([^"']+)["'](?:\s*,\s*["']([^"']+)["'])?/)
        next unless gem_match

        declaration = metadata.fetch(gem_match[1], []).find { |item| item[:line_number] == index + 1 } || {}
        entries << GemEntry.new(
          name: gem_match[1],
          version: gem_match[2],
          groups: groups.flatten,
          line_number: declaration[:line_number] || index + 1,
          source_line: declaration[:source_line] || line
        )
      end

      entries
    end

    def lockfile_parser
      return nil unless File.exist?(lockfile_path)

      @lockfile_parser ||= Bundler::LockfileParser.new(Bundler.read_file(lockfile_path))
    rescue StandardError
      nil
    end
  end
end
