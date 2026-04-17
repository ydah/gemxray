# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module GemXray
  class ArchiveChecker
    MAX_REDIRECTS = 5
    GITHUB_API = "https://api.github.com/repos/"

    ArchiveResult = Struct.new(:owner_repo, :archived, :error, keyword_init: true)

    def initialize(token:)
      @token = token
    end

    def check(owner_repo)
      archived, error = fetch_archive_status(owner_repo)
      ArchiveResult.new(owner_repo: owner_repo, archived: archived, error: error)
    end

    private

    def fetch_archive_status(owner_repo, redirects_remaining = MAX_REDIRECTS)
      uri = URI("#{GITHUB_API}#{owner_repo}")
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["Authorization"] = "Bearer #{@token}" if @token

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.open_timeout = 10
        http.read_timeout = 10
        http.request(request)
      end

      handle_response(response, redirects_remaining)
    rescue StandardError => e
      [nil, e.message]
    end

    def handle_response(response, redirects_remaining)
      code = response.code.to_i
      case code
      when 200..299
        data = JSON.parse(response.body)
        [data["archived"] == true, nil]
      when 301, 302, 307, 308
        return [nil, "too many redirects"] if redirects_remaining <= 0

        new_url = response["location"]
        new_repo = extract_repo_from_api_url(new_url)
        return [nil, "invalid redirect"] unless new_repo

        fetch_archive_status(new_repo, redirects_remaining - 1)
      when 404
        [nil, "repository not found"]
      when 401
        [nil, "authentication failed"]
      when 403
        [nil, "rate limit exceeded or access denied"]
      else
        [nil, "unexpected response: #{code}"]
      end
    end

    def extract_repo_from_api_url(url)
      return unless url

      match = url.match(%r{api\.github\.com/repos/([^?]+)})
      match&.[](1)
    end
  end
end
