# frozen_string_literal: true

require "bundler"

module GemXray
  class GemfileParser
    DependencyEdge = Struct.new(:name, :requirement, keyword_init: true)

    attr_reader :gemfile_path, :lockfile_path

    def initialize(gemfile_path)
      @gemfile_path = File.expand_path(gemfile_path)
      @lockfile_path = "#{@gemfile_path}.lock"
    end

    def parse
      @parse ||= begin
        dependencies = bundler_dependencies
        metadata = source_metadata.group_by(&:name)

        if dependencies.empty?
          source_metadata.map { |entry| build_entry_from_metadata(entry, []) }
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
        tree[spec.name] = spec.dependencies.map do |dependency|
          DependencyEdge.new(name: dependency.name, requirement: dependency.requirement)
        end
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

    def resolved_version(gem_name)
      parser = lockfile_parser
      return nil unless parser

      parser.specs.find { |spec| spec.name == gem_name }&.version
    end

    private

    def bundler_dependencies
      Bundler::Dsl.evaluate(gemfile_path, nil, {}).dependencies
    rescue StandardError
      []
    end

    def build_entry_from_dependency(dependency, metadata)
      declaration = metadata.fetch(dependency.name, []).shift
      declaration ||= GemfileSourceParser::Metadata.new(name: dependency.name, options: {})
      GemEntry.new(
        name: dependency.name,
        version: normalized_requirement(dependency.requirement),
        groups: dependency.groups.empty? ? declaration.groups : dependency.groups,
        line_number: declaration.line_number,
        end_line: declaration.end_line,
        source_line: declaration.source_line,
        autorequire: declaration.options.fetch(:require, dependency.autorequire),
        options: declaration.options
      )
    end

    def build_entry_from_metadata(metadata_entry, default_groups)
      options = metadata_entry.options
      GemEntry.new(
        name: metadata_entry.name,
        version: metadata_entry.version,
        groups: default_groups + metadata_entry.groups.to_a + extract_inline_groups(options),
        line_number: metadata_entry.line_number,
        end_line: metadata_entry.end_line,
        source_line: metadata_entry.source_line,
        autorequire: options[:require],
        options: options
      )
    end

    def normalized_requirement(requirement)
      return nil unless requirement

      text = Array(requirement.as_list).join(", ").strip
      text.empty? || text == ">= 0" ? nil : text
    end

    def source_metadata
      @source_metadata ||= GemfileSourceParser.new(gemfile_path).parse
    end

    def extract_inline_groups(options)
      values = []
      values.concat(Array(options[:group]))
      values.concat(Array(options[:groups]))
      values.map { |value| value.to_s.delete_prefix(":").to_sym }
    end

    def lockfile_parser
      return nil unless File.exist?(lockfile_path)

      @lockfile_parser ||= Bundler::LockfileParser.new(Bundler.read_file(lockfile_path))
    rescue StandardError
      nil
    end
  end
end
