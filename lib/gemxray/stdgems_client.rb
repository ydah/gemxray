# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "uri"

module GemXray
  class StdgemsClient
    CACHE_TTL = 86_400
    DEFAULT_GEMS_URI = URI("https://stdgems.org/default_gems.json")
    BUNDLED_GEMS_URI = URI("https://stdgems.org/bundled_gems.json")
    FALLBACK_DEFAULT_GEMS = {
      "3.1" => %w[
        abbrev base64 benchmark bigdecimal cgi csv date delegate did_you_mean
        digest drb english erb error_highlight fileutils find io-console
        irb json logger mutex_m net-http net-imap net-pop net-protocol
        net-smtp observer open-uri open3 openssl optparse ostruct pp prettyprint
        prime pstore psych rake rdoc readline resolv rexml rss ruby2_keywords
        securerandom set shell socket stringio strscan tempfile time timeout
        tmpdir tsort typeprof un uri weakref yaml zlib
      ],
      "3.2" => %w[
        abbrev base64 benchmark bigdecimal cgi csv date delegate did_you_mean
        digest drb english erb error_highlight fileutils find io-console
        irb json logger mutex_m net-http net-imap net-pop net-protocol
        net-smtp observer open-uri open3 openssl optparse ostruct pp prettyprint
        prime pstore psych rake rdoc readline resolv rexml rss securerandom
        set shell socket stringio strscan syntax_suggest tempfile time timeout
        tmpdir tsort un uri weakref yaml zlib
      ],
      "3.3" => %w[
        abbrev base64 benchmark bigdecimal cgi csv date delegate did_you_mean
        digest drb english erb error_highlight fileutils find io-console
        irb json logger mutex_m net-http net-imap net-pop net-protocol
        net-smtp observer open-uri open3 openssl optparse ostruct pp prettyprint
        prime pstore psych rake rdoc readline resolv rexml rss securerandom
        set shell socket stringio strscan syntax_suggest tempfile time timeout
        tmpdir tsort un uri weakref yaml zlib
      ],
      "4.0" => Gem::Specification.select { |spec| spec.respond_to?(:default_gem?) && spec.default_gem? }.map(&:name).sort
    }.freeze

    def initialize(cache_dir: File.join(Dir.home, ".gemxray", "cache"))
      @cache_dir = cache_dir
    end

    def default_gems_for(version)
      version_key = normalize_version(version)
      extracted = extract_default_gems(payload_for(:default), version_key)

      return extracted if extracted && !extracted.empty?

      fallback_default_gems(version_key)
    end

    def bundled_gems_for(version)
      version_key = normalize_version(version)
      extract_default_gems(payload_for(:bundled), version_key) || []
    end

    private

    attr_reader :cache_dir

    def cache_path(kind)
      File.join(cache_dir, "#{kind}_gems.json")
    end

    def normalize_version(version)
      version.to_s[/\d+\.\d+/] || RUBY_VERSION[/\d+\.\d+/]
    end

    def payload_for(kind)
      cached_payload(kind) || fetch_and_cache_payload(kind)
    end

    def cached_payload(kind)
      return nil unless File.exist?(cache_path(kind))
      return nil if Time.now - File.mtime(cache_path(kind)) > CACHE_TTL

      JSON.parse(File.read(cache_path(kind)))
    rescue StandardError
      nil
    end

    def fetch_and_cache_payload(kind)
      response = Net::HTTP.get_response(kind == :bundled ? BUNDLED_GEMS_URI : DEFAULT_GEMS_URI)
      return nil unless response.is_a?(Net::HTTPSuccess)

      FileUtils.mkdir_p(cache_dir)
      File.write(cache_path(kind), response.body)
      JSON.parse(response.body)
    rescue StandardError
      nil
    end

    def extract_default_gems(payload, version_key)
      return nil unless payload

      case payload
      when Hash
        extract_from_hash(payload, version_key)
      when Array
        extract_from_array(payload, version_key)
      end
    end

    def extract_from_hash(payload, version_key)
      candidates = [
        payload[version_key],
        payload.dig("default_gems", version_key),
        payload.dig(version_key, "default_gems")
      ].compact

      return normalize_payload_list(candidates.first) unless candidates.empty?

      payload.each do |key, value|
        return normalize_payload_list(value) if key.to_s.start_with?(version_key)
      end

      nil
    end

    def extract_from_array(payload, version_key)
      matched = payload.select do |item|
        next false unless item.is_a?(Hash)

        item_version = item["ruby_version"] || item["version"]
        item_version.to_s.start_with?(version_key)
      end

      names = matched.filter_map { |item| item["name"] || item["gem"] }.uniq
      names.empty? ? nil : names.sort
    end

    def normalize_payload_list(value)
      case value
      when Array
        value.map do |item|
          item.is_a?(Hash) ? (item["name"] || item["gem"]) : item
        end.compact.map(&:to_s).sort
      when Hash
        value.keys.map(&:to_s).sort
      end
    end

    def fallback_default_gems(version_key)
      exact = FALLBACK_DEFAULT_GEMS[version_key]
      return exact if exact

      major_minor = FALLBACK_DEFAULT_GEMS.keys.sort.reverse.find { |key| key <= version_key }
      FALLBACK_DEFAULT_GEMS[major_minor] || []
    end
  end
end
