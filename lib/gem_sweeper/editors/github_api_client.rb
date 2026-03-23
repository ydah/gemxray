# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module GemSweeper
  module Editors
    class GithubApiClient
      API_BASE = URI("https://api.github.com").freeze

      def initialize(token:, repository:)
        @token = token
        @repository = repository
      end

      def create_pull_request(base:, head:, title:, body:, labels:, reviewers:)
        pr = post_json("/repos/#{repository}/pulls", {
                         title: title,
                         head: head,
                         base: base,
                         body: body
                       })

        issue_number = pr.fetch("number")
        post_json("/repos/#{repository}/issues/#{issue_number}/labels", { labels: labels }) unless labels.empty?
        post_json("/repos/#{repository}/pulls/#{issue_number}/requested_reviewers", { reviewers: reviewers }) unless reviewers.empty?

        pr.fetch("html_url")
      end

      private

      attr_reader :token, :repository

      def post_json(path, payload)
        uri = API_BASE.dup
        uri.path = path

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          request = Net::HTTP::Post.new(uri)
          request["Accept"] = "application/vnd.github+json"
          request["Authorization"] = "Bearer #{token}"
          request["X-GitHub-Api-Version"] = "2022-11-28"
          request["Content-Type"] = "application/json"
          request.body = JSON.dump(payload)
          http.request(request)
        end

        raise Error, "GitHub API request failed: #{response.code} #{response.body}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)
      end
    end
  end
end
