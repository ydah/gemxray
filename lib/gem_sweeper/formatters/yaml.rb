# frozen_string_literal: true

require "yaml"

module GemSweeper
  module Formatters
    class Yaml
      def render(report)
        ::YAML.dump(report.to_h)
      end
    end
  end
end
