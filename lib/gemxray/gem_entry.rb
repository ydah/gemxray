# frozen_string_literal: true

module GemXray
  class GemEntry
    attr_reader :name, :version, :groups, :line_number, :end_line, :source_line, :autorequire, :options

    def initialize(name:, version: nil, groups: [], line_number: nil, end_line: nil, source_line: nil, autorequire: nil,
                   options: {})
      @name = name
      @version = normalize_version(version)
      @groups = Array(groups).map(&:to_sym).reject { |group| group == :default }.uniq
      @line_number = line_number
      @end_line = end_line || line_number
      @source_line = source_line
      @autorequire = autorequire
      @options = options
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

    def line_range
      return nil unless line_number

      line_number..(end_line || line_number)
    end

    def require_names
      case autorequire
      when false
        []
      when nil
        default_require_names
      else
        Array(autorequire).compact.map(&:to_s).uniq
      end
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
