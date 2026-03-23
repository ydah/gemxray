# frozen_string_literal: true

require "json"

module GemSweeper
  module Formatters
    class Json
      def render(report)
        JSON.pretty_generate(report.to_h)
      end
    end
  end
end
