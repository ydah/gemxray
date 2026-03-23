# frozen_string_literal: true

require "ripper"

module GemSweeper
  class GemfileSourceParser
    Metadata = Struct.new(
      :name,
      :version,
      :groups,
      :options,
      :line_number,
      :end_line,
      :source_line,
      :statement,
      keyword_init: true
    )

    def initialize(gemfile_path)
      @gemfile_path = gemfile_path
    end

    def parse
      lines = File.readlines(gemfile_path, chomp: false)
      entries = []
      block_stack = []
      index = 0

      while index < lines.length
        stripped = lines[index].strip

        if group_block_start?(stripped)
          block_stack << { type: :group, groups: parse_group_names(stripped) }
          index += 1
          next
        end

        if generic_block_start?(stripped)
          block_stack << { type: :block, groups: [] }
          index += 1
          next
        end

        if stripped == "end"
          block_stack.pop
          index += 1
          next
        end

        unless gem_statement_start?(lines[index])
          index += 1
          next
        end

        start_index = index
        statement_lines = [lines[index]]
        until syntax_complete?(statement_lines.join)
          index += 1
          break if index >= lines.length

          statement_lines << lines[index]
        end

        metadata = parse_statement(statement_lines.join, start_index + 1, current_groups(block_stack))
        entries << metadata if metadata
        index += 1
      end

      entries
    end

    private

    attr_reader :gemfile_path

    def gem_statement_start?(line)
      stripped = line.lstrip
      return false if stripped.start_with?("#")

      stripped.match?(/\Agem(?:\s|\()/)
    end

    def syntax_complete?(statement)
      !Ripper.sexp("begin\n#{statement}\nend\n").nil?
    end

    def parse_statement(statement, start_line, groups)
      recorder = GemInvocationRecorder.new
      recorder.instance_eval(statement, gemfile_path, start_line)
      invocation = recorder.invocation
      return nil unless invocation

      Metadata.new(
        name: invocation.fetch(:name),
        version: invocation[:version],
        groups: groups,
        options: invocation[:options],
        line_number: start_line,
        end_line: start_line + statement.lines.size - 1,
        source_line: statement.lines.first&.chomp,
        statement: statement
      )
    rescue StandardError
      nil
    end

    class GemInvocationRecorder
      attr_reader :invocation

      def gem(name, *args)
        options = args.last.is_a?(Hash) ? args.pop.dup : {}
        @invocation = {
          name: name.to_s,
          version: args.find { |value| value.is_a?(String) || value.is_a?(Gem::Requirement) }&.to_s,
          options: symbolize_keys(options)
        }
      end

      private

      def symbolize_keys(hash)
        hash.each_with_object({}) do |(key, value), result|
          result[key.to_sym] = value
        end
      end
    end

    def group_block_start?(line)
      line.match?(/\Agroup\s+.+\s+do\s*\z/)
    end

    def generic_block_start?(line)
      return false if line.start_with?("#")
      return false if group_block_start?(line)

      line.match?(/\bdo\b\s*(\|.*\|)?\s*\z/)
    end

    def parse_group_names(line)
      line
        .sub(/\Agroup\s+/, "")
        .sub(/\s+do\s*\z/, "")
        .split(",")
        .map { |item| item.strip.delete_prefix(":").delete_prefix('"').delete_suffix('"').delete_prefix("'").delete_suffix("'").to_sym }
    end

    def current_groups(block_stack)
      block_stack.flat_map { |entry| entry[:groups] }.uniq
    end
  end
end
