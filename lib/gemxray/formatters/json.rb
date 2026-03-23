# frozen_string_literal: true

require "json"

module GemXray
  module Formatters
    class Json
      def render(report)
        JSON.pretty_generate(report.to_h)
      end
    end
  end
end
