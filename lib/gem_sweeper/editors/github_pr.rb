# frozen_string_literal: true

require "open3"
require "pathname"

module GemSweeper
  module Editors
    class GithubPr
      attr_reader :config

      def initialize(config)
        @config = config
      end

      def create(results, per_gem: config.github_per_gem?, bundle_install: config.bundle_install?, comment: false)
        ensure_git_repository!

        branch_name = "gem-sweeper/cleanup-#{Time.now.strftime('%Y%m%d')}"
        run!("git", "switch", "-c", branch_name)

        editor = GemfileEditor.new(config.gemfile_path)
        commits = if per_gem
                    create_per_gem_commits(editor, results, bundle_install: bundle_install, comment: comment)
                  else
                    [create_single_commit(editor, results, bundle_install: bundle_install, comment: comment)]
                  end.compact

        raise Error, "no Gemfile changes were created" if commits.empty?

        pr_url = create_pull_request!(results, branch_name)
        { branch: branch_name, commits: commits, pr_url: pr_url }
      end

      private

      def create_per_gem_commits(editor, results, bundle_install:, comment:)
        results.filter_map do |result|
          outcome = editor.apply([result], dry_run: false, comment: comment, backup: false)
          next if outcome.removed.empty?

          editor.bundle_install! if bundle_install
          commit_message = "chore: remove #{result.gem_name} from Gemfile"
          stage_and_commit!(commit_message)
        end
      end

      def create_single_commit(editor, results, bundle_install:, comment:)
        outcome = editor.apply(results, dry_run: false, comment: comment, backup: false)
        return nil if outcome.removed.empty?

        editor.bundle_install! if bundle_install
        commit_message = if outcome.removed.one?
                           "chore: remove #{outcome.removed.first} from Gemfile"
                         else
                           "chore: sweep redundant gems"
                         end
        stage_and_commit!(commit_message)
      end

      def stage_and_commit!(message)
        files = [relative_path(config.gemfile_path)]
        lockfile = "#{config.gemfile_path}.lock"
        files << relative_path(lockfile) if File.exist?(lockfile)

        run!("git", "add", *files)
        run!("git", "commit", "-m", message)
        message
      end

      def create_pull_request!(results, branch_name)
        title = "chore: gem-sweeper cleanup"
        body = build_pr_body(results, branch_name)
        command = ["gh", "pr", "create", "--base", config.github_base_branch, "--title", title, "--body", body]

        config.github_labels.each do |label|
          command += ["--label", label]
        end

        config.github_reviewers.each do |reviewer|
          command += ["--reviewer", reviewer]
        end

        run!(*command).strip
      end

      def build_pr_body(results, branch_name)
        <<~BODY
          ## Summary

          gem-sweeper generated this cleanup on branch `#{branch_name}`.

          #{results.map { |result| "- `#{result.gem_name}`: #{result.reasons.map(&:detail).join(' / ')}" }.join("\n")}

          ## Checklist

          - [ ] アプリ起動確認
          - [ ] 主要ワークフロー確認
          - [ ] `bundle exec rake spec`
        BODY
      end

      def ensure_git_repository!
        run!("git", "rev-parse", "--git-dir")
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
    end
  end
end
