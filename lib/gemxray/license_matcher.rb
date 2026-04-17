# frozen_string_literal: true

module GemXray
  class LicenseMatcher
    NOISE_WORDS = %w[the license version v].freeze

    def match?(license, allowed_list)
      return false if allowed_list.empty?

      allowed_list.any? do |allowed|
        exact_match?(license, allowed) || fingerprint_match?(license, allowed)
      end
    end

    private

    def exact_match?(license, allowed)
      license.downcase.strip == allowed.downcase.strip
    end

    def fingerprint_match?(license, allowed)
      fingerprint(license) == fingerprint(allowed)
    end

    def fingerprint(text)
      normalized = text.downcase.gsub(/[^a-z0-9\s]/, " ")
      words = normalized.split - NOISE_WORDS
      words.join
    end
  end
end
