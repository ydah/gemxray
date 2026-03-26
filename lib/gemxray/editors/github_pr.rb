# frozen_string_literal: true

require "open3"
require "pathname"

module GemXray
  module Editors
    class GithubPr
      attr_reader :config

      def initialize(config)
        @config = config
      end

      def create(results, per_gem: config.github_per_gem?, bundle_install: config.github_bundle_install?, comment: false)
        ensure_git_repository!
        ensure_clean_worktree!

        pull_requests =
          if per_gem
            create_per_gem_pull_requests(results, bundle_install: bundle_install, comment: comment)
          else
            [create_single_pull_request(results, bundle_install: bundle_install, comment: comment)]
          end

        raise Error, "no Gemfile changes were created" if pull_requests.empty?

        primary = pull_requests.first
        {
          branch: primary[:branch],
          commits: primary[:commits],
          pr_url: primary[:pr_url],
          pull_requests: pull_requests
        }
      end

      private

      def create_single_pull_request(results, bundle_install:, comment:)
        branch_name = branch_name_for
        create_branch_from_base!(branch_name)

        editor = GemfileEditor.new(config.gemfile_path)
        commits = [create_single_commit(editor, results, comment: comment)].compact
        lockfile_commit = install_and_commit_lockfile(editor) if bundle_install
        commits << lockfile_commit if lockfile_commit

        raise Error, "no Gemfile changes were created" if commits.empty?

        push_branch!(branch_name)
        pr_url = create_pull_request!(results, branch_name)
        { branch: branch_name, commits: commits, pr_url: pr_url, gem_names: results.map(&:gem_name) }
      end

      def create_per_gem_pull_requests(results, bundle_install:, comment:)
        results.filter_map do |result|
          branch_name = branch_name_for(result.gem_name)
          create_branch_from_base!(branch_name)

          editor = GemfileEditor.new(config.gemfile_path)
          commits = [create_single_commit(editor, [result], comment: comment)].compact
          lockfile_commit = install_and_commit_lockfile(editor) if bundle_install
          commits << lockfile_commit if lockfile_commit
          next if commits.empty?

          push_branch!(branch_name)
          pr_url = create_pull_request!([result], branch_name)
          {
            gem_name: result.gem_name,
            branch: branch_name,
            commits: commits,
            pr_url: pr_url
          }
        ensure
          checkout_base_branch!
        end
      end

      def install_and_commit_lockfile(editor)
        editor.bundle_install!
        lockfile = "#{config.gemfile_path}.lock"
        return nil unless File.exist?(lockfile)
        return nil unless tracked_changes?(relative_path(lockfile))

        stage_and_commit!("chore: refresh Gemfile.lock after gem sweep", relative_path(lockfile))
      end

      def stage_and_commit!(message, *files)
        run!("git", "add", *files)
        run!("git", "commit", "-m", message)
        message
      end

      def create_single_commit(editor, results, comment:)
        outcome = editor.apply(results, dry_run: false, comment: comment, backup: false)
        return nil if outcome.removed.empty?

        commit_message = if outcome.removed.one?
                           "chore: remove #{outcome.removed.first} from Gemfile"
                         else
                           "chore: sweep redundant gems"
                         end
        stage_and_commit!(commit_message, relative_path(config.gemfile_path))
      end

      def create_pull_request!(results, branch_name)
        title = "chore: gemxray cleanup"
        body = build_pr_body(results, branch_name)
        create_pull_request_with_gh(title: title, body: body, branch_name: branch_name) || create_pull_request_with_api(
          title: title,
          body: body,
          branch_name: branch_name
        )
      end

      def build_pr_body(results, branch_name)
        <<~BODY
          ## Summary

          gemxray generated this cleanup on branch `#{branch_name}`.

          ## Removed Gems

          #{results.map { |result| "- `#{result.gem_name}`" }.join("\n")}

          ## Detection Grounds

          #{results.map { |result| "- `#{result.gem_name}`: #{result.reasons.map(&:detail).join(' / ')}" }.join("\n")}

          ## Checklist

          - [ ] App boot check
          - [ ] Primary workflow check
          - [ ] `bundle exec rake spec`
        BODY
      end

      def ensure_git_repository!
        run!("git", "rev-parse", "--git-dir")
      end

      def ensure_clean_worktree!
        raise Error, "git worktree must be clean before creating a cleanup PR" if tracked_changes?
      end

      def create_branch_from_base!(branch_name)
        checkout_base_branch!
        run!("git", "switch", "-c", branch_name)
      end

      def checkout_base_branch!
        run!("git", "switch", config.github_base_branch)
      end

      def push_branch!(branch_name)
        run!("git", "push", "-u", "origin", branch_name)
      end

      def run!(*command)
        stdout, stderr, status = Open3.capture3(*command, chdir: config.project_root)
        return stdout if status.success?

        message = [stderr, stdout].map(&:strip).reject(&:empty?).first
        raise Error, "#{command.join(' ')} failed: #{message}"
      end

      def relative_path(path)
        Pathname.new(path).relative_path_from(Pathname.new(config.project_root)).to_s
      end

      def tracked_changes?(*paths)
        args = ["git", "status", "--short"]
        args.concat(paths) unless paths.empty?
        !run!(*args).strip.empty?
      rescue Error
        true
      end

      def create_pull_request_with_gh(title:, body:, branch_name:)
        command = ["gh", "pr", "create", "--base", config.github_base_branch, "--head", branch_name, "--title", title,
                   "--body", body]
        config.github_labels.each { |label| command += ["--label", label] }
        config.github_reviewers.each { |reviewer| command += ["--reviewer", reviewer] }
        run!(*command).strip
      rescue Error
        nil
      end

      def create_pull_request_with_api(title:, body:, branch_name:)
        token = ENV["GH_TOKEN"] || ENV["GITHUB_TOKEN"]
        raise Error, "gh is unavailable and no GitHub token is configured for API fallback" if token.to_s.empty?

        client = GithubApiClient.new(token: token, repository: repository_slug)
        client.create_pull_request(
          base: config.github_base_branch,
          head: branch_name,
          title: title,
          body: body,
          labels: config.github_labels,
          reviewers: config.github_reviewers
        )
      end

      def repository_slug
        return ENV["GITHUB_REPOSITORY"] unless ENV["GITHUB_REPOSITORY"].to_s.empty?

        remote = run!("git", "remote", "get-url", "origin").strip
        remote[%r{github\.com[:/](.+?)(?:\.git)?$}, 1] || raise(Error, "cannot determine GitHub repository from git remote")
      end

      def branch_name_for(gem_name = nil)
        suffix = sanitize_branch_component(gem_name)
        base = "gemxray/cleanup-#{Time.now.strftime('%Y%m%d')}"
        suffix.empty? ? base : "#{base}-#{suffix}"
      end

      def sanitize_branch_component(value)
        value.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
      end
    end
  end
end
