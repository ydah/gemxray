# frozen_string_literal: true

require "date"
require "digest"
require "fileutils"
require "json"
require "net/http"
require "uri"
require "yaml"

module GemXray
  class SecurityAdvisoryFetcher
    CACHE_TTL = 86_400
    GITHUB_CONTENTS_API = "https://api.github.com/repos/rubysec/ruby-advisory-db/contents/gems"

    Advisory = Struct.new(
      :gem_name,
      :id,
      :url,
      :title,
      :cve,
      :ghsa,
      :osvdb,
      :patched_versions,
      :unaffected_versions,
      :date,
      :source,
      keyword_init: true
    ) do
      def identifier
        normalized = normalized_cve
        return normalized unless normalized.empty?
        return ghsa.to_s unless ghsa.to_s.empty?
        return id.to_s unless id.to_s.empty?
        return "OSVDB-#{osvdb}" unless osvdb.to_s.empty?

        title.to_s.empty? ? "advisory" : title.to_s
      end

      def vulnerable?(version)
        gem_version = Gem::Version.new(version.to_s)
        return false if requirement_set_satisfied?(unaffected_versions, gem_version)
        return false if patched_versions.any? && requirement_set_satisfied?(patched_versions, gem_version)

        true
      rescue ArgumentError, Gem::Requirement::BadRequirementError
        false
      end

      def patched_versions_text
        patched_versions.empty? ? "no patched version listed" : patched_versions.join(", ")
      end

      def to_h
        {
          gem_name: gem_name,
          id: id,
          url: url,
          title: title,
          cve: cve,
          ghsa: ghsa,
          osvdb: osvdb,
          patched_versions: patched_versions,
          unaffected_versions: unaffected_versions,
          date: date,
          source: source.to_s
        }
      end

      private

      def normalized_cve
        text = cve.to_s.strip
        return "" if text.empty?

        text.start_with?("CVE-") ? text : "CVE-#{text}"
      end

      def requirement_set_satisfied?(requirements, version)
        Array(requirements).any? { |requirement| requirement_satisfied?(requirement, version) }
      end

      def requirement_satisfied?(requirement, version)
        parts = requirement.to_s.split(",").map(&:strip).reject(&:empty?)
        return false if parts.empty?

        parts.all? { |part| Gem::Requirement.new(part).satisfied_by?(version) }
      end
    end

    def initialize(advisory_db_path: nil, cache_dir: File.join(Dir.home, ".gemxray", "cache", "security"),
                   cache_ttl: CACHE_TTL, github_token: nil, ref: "master")
      @advisory_db_path = advisory_db_path
      @cache_dir = cache_dir
      @cache_ttl = cache_ttl.to_i
      @github_token = github_token
      @ref = ref
      @memory_cache = {}
    end

    def fetch(gem_name)
      @memory_cache[gem_name.to_s] ||= fetch_uncached(gem_name.to_s)
    end

    private

    attr_reader :advisory_db_path, :cache_dir, :cache_ttl, :github_token, :ref

    def fetch_uncached(gem_name)
      local_advisories = fetch_from_local_db(gem_name)
      return local_advisories if local_advisories

      cached_advisories(gem_name) || fetch_remote_and_cache(gem_name) || []
    end

    def fetch_from_local_db(gem_name)
      return nil if advisory_db_path.to_s.empty?

      gem_dir = File.join(advisory_db_path, "gems", gem_name)
      return nil unless Dir.exist?(gem_dir)

      Dir[File.join(gem_dir, "*.{yml,yaml}")].sort.filter_map do |path|
        parse_advisory(File.read(path), source: path)
      end
    rescue StandardError
      []
    end

    def cached_advisories(gem_name)
      return nil unless cache_ttl.positive?

      path = cache_path(gem_name)
      return nil unless File.exist?(path)
      return nil if Time.now - File.mtime(path) > cache_ttl

      Array(JSON.parse(File.read(path))).filter_map { |payload| build_advisory(payload) }
    rescue StandardError
      nil
    end

    def fetch_remote_and_cache(gem_name)
      advisories = fetch_from_remote_db(gem_name)
      write_cache(gem_name, advisories) if advisories && cache_ttl.positive?
      advisories
    end

    def fetch_from_remote_db(gem_name)
      entries = fetch_json(remote_list_uri(gem_name))
      return [] if entries.is_a?(Hash) && entries["message"].to_s.match?(/not found/i)
      return [] unless entries.is_a?(Array)

      entries.filter_map do |entry|
        next unless entry["type"] == "file"
        next unless entry["name"].to_s.match?(/\.ya?ml\z/)

        body = fetch_text(entry["download_url"])
        parse_advisory(body, source: entry["html_url"] || entry["download_url"] || entry["url"]) if body
      end
    rescue StandardError
      nil
    end

    def remote_list_uri(gem_name)
      escaped_gem = URI.encode_www_form_component(gem_name)
      URI("#{GITHUB_CONTENTS_API}/#{escaped_gem}?ref=#{URI.encode_www_form_component(ref)}")
    end

    def fetch_json(uri)
      response = request(uri)
      return nil unless response&.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    end

    def fetch_text(url)
      return nil if url.to_s.empty?

      response = request(URI(url))
      return nil unless response&.is_a?(Net::HTTPSuccess)

      response.body
    rescue StandardError
      nil
    end

    def request(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json" if uri.host == "api.github.com"
      request["Authorization"] = "Bearer #{github_token}" unless github_token.to_s.empty?
      request["User-Agent"] = "gemxray/#{GemXray::VERSION}"

      http.request(request)
    rescue StandardError
      nil
    end

    def write_cache(gem_name, advisories)
      FileUtils.mkdir_p(cache_dir)
      File.write(cache_path(gem_name), JSON.generate(advisories.map(&:to_h)))
    rescue StandardError
      nil
    end

    def cache_path(gem_name)
      File.join(cache_dir, "#{Digest::SHA256.hexdigest(gem_name)}.json")
    end

    def parse_advisory(body, source:)
      payload = YAML.safe_load(body, permitted_classes: [Date, Time], aliases: true)
      return nil unless payload.is_a?(Hash)

      payload["source"] ||= source
      build_advisory(payload)
    rescue StandardError
      nil
    end

    def build_advisory(payload)
      Advisory.new(
        gem_name: value_for(payload, "gem"),
        id: value_for(payload, "id"),
        url: value_for(payload, "url"),
        title: value_for(payload, "title"),
        cve: value_for(payload, "cve"),
        ghsa: value_for(payload, "ghsa"),
        osvdb: value_for(payload, "osvdb"),
        patched_versions: version_list(value_for(payload, "patched_versions")),
        unaffected_versions: version_list(value_for(payload, "unaffected_versions")),
        date: value_for(payload, "date").to_s,
        source: value_for(payload, "source")
      )
    end

    def value_for(payload, key)
      payload[key] || payload[key.to_sym]
    end

    def version_list(value)
      Array(value).map(&:to_s).map(&:strip).reject(&:empty?)
    end
  end
end
