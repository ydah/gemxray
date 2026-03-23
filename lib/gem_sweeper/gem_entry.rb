# frozen_string_literal: true

module GemSweeper
  class GemEntry
    attr_reader :name, :version, :groups, :line_number, :source_line, :autorequire

    def initialize(name:, version: nil, groups: [], line_number: nil, source_line: nil, autorequire: nil)
      @name = name
      @version = normalize_version(version)
      @groups = Array(groups).map(&:to_sym).reject { |group| group == :default }.uniq
      @line_number = line_number
      @source_line = source_line
      @autorequire = autorequire
    end

    def pinned_version?
      !version.nil?
    end

    def development_group?
      !(groups & %i[development test]).empty?
    end

    def gemfile_group
      return nil if groups.empty?
      return groups.first.to_s if groups.one?

      groups.map(&:to_s)
    end

    def require_names
      candidates =
        case autorequire
        when false
          []
        when nil
          default_require_names
        else
          Array(autorequire).compact.map(&:to_s)
        end

      (candidates + default_require_names).uniq
    end

    private

    def normalize_version(value)
      return nil if value.nil?

      text = value.to_s.strip
      text.empty? || text == ">= 0" ? nil : text
    end

    def default_require_names
      [name, name.tr("-", "/"), name.tr("-", "_")].uniq
    end
  end
end
