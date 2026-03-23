# frozen_string_literal: true

module GemXray
  class Result
    SEVERITIES = { danger: 0, warning: 1, info: 2 }.freeze

    Reason = Struct.new(:type, :detail, :severity, keyword_init: true) do
      def to_h
        { type: type.to_s, detail: detail }
      end
    end

    attr_reader :gem_name, :gemfile_line, :gemfile_end_line, :gemfile_group, :suggestion, :reasons
    attr_accessor :severity

    def initialize(gem_name:, gemfile_line: nil, gemfile_end_line: nil, gemfile_group: nil, suggestion: nil,
                   reasons: [], severity: nil)
      @gem_name = gem_name
      @gemfile_line = gemfile_line
      @gemfile_end_line = gemfile_end_line || gemfile_line
      @gemfile_group = gemfile_group
      @suggestion = suggestion || "Consider removing this entry from Gemfile"
      @reasons = reasons.dup
      @severity = severity || infer_severity
    end

    def add_reason(type:, detail:, severity:)
      reasons << Reason.new(type: type.to_sym, detail: detail, severity: severity.to_sym)
      self.severity = infer_severity
      self
    end

    def merge!(other)
      other.reasons.each do |reason|
        add_reason(type: reason.type, detail: reason.detail, severity: reason.severity)
      end
      self.gemfile_line ||= other.gemfile_line
      self.gemfile_end_line ||= other.gemfile_end_line
      self.gemfile_group ||= other.gemfile_group
      self.suggestion ||= other.suggestion
      self
    end

    def severity_order
      SEVERITIES.fetch(severity)
    end

    def reason_types
      reasons.map(&:type).uniq
    end

    def type_label
      reason_types.map { |type| type.to_s.tr("_", "-") }.join(" + ")
    end

    def danger?
      severity == :danger
    end

    def info?
      severity == :info
    end

    def to_h
      {
        gem_name: gem_name,
        severity: severity.to_s,
        reasons: reasons.map(&:to_h),
        gemfile_line: gemfile_line,
        gemfile_group: gemfile_group,
        suggestion: suggestion
      }
    end

    protected

    attr_writer :gemfile_line, :gemfile_end_line, :gemfile_group, :suggestion

    private

    def infer_severity
      severities = reasons.map(&:severity)
      severities.min_by { |value| SEVERITIES.fetch(value) } || :info
    end
  end
end
