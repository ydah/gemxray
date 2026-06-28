# frozen_string_literal: true

require "json"
require "net/http"
require "time"
require "uri"

module GemXray
  class UnmaintainedChecker
    GITHUB_API = "https://api.github.com/repos/"

    ActivityResult = Struct.new(:owner_repo, :pushed_at, :latest_release_at, :error, keyword_init: true) do
      def last_activity_at
        [parse_time(pushed_at), parse_time(latest_release_at)].compact.max
      end

      def unmaintained?(threshold_time)
        activity = last_activity_at
        activity && activity < threshold_time
      end

      private

      def parse_time(value)
        Time.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end

    def initialize(token:)
      @token = token
    end

    def check(owner_repo)
      repo_data, error = fetch_json(repo_uri(owner_repo))
      return ActivityResult.new(owner_repo: owner_repo, error: error) unless repo_data

      release_data, release_error = fetch_json(latest_release_uri(owner_repo))
      latest_release_at = release_data && release_data["published_at"]
      error = release_error unless release_error == "release not found"

      ActivityResult.new(
        owner_repo: owner_repo,
        pushed_at: repo_data["pushed_at"],
        latest_release_at: latest_release_at,
        error: error
      )
    end

    private

    attr_reader :token

    def repo_uri(owner_repo)
      URI("#{GITHUB_API}#{owner_repo}")
    end

    def latest_release_uri(owner_repo)
      URI("#{GITHUB_API}#{owner_repo}/releases/latest")
    end

    def fetch_json(uri)
      response = request(uri)
      handle_response(response, latest_release: latest_release_uri?(uri))
    rescue StandardError => e
      [nil, e.message]
    end

    def request(uri)
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "application/vnd.github+json"
      request["Authorization"] = "Bearer #{token}" if token

      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        http.open_timeout = 10
        http.read_timeout = 10
        http.request(request)
      end
    end

    def handle_response(response, latest_release:)
      code = response.code.to_i
      case code
      when 200..299
        [JSON.parse(response.body), nil]
      when 404
        [nil, latest_release ? "release not found" : "repository not found"]
      when 401
        [nil, "authentication failed"]
      when 403
        [nil, "rate limit exceeded or access denied"]
      else
        [nil, "unexpected response: #{code}"]
      end
    rescue JSON::ParserError => e
      [nil, e.message]
    end

    def latest_release_uri?(uri)
      uri.path.end_with?("/releases/latest")
    end
  end
end
