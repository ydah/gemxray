# frozen_string_literal: true

RSpec.describe GemXray::Editors::GithubPr do
  it "runs bundle install by default for PR creation and commits the lockfile" do
    with_project(sample_project_files) do |project_dir|
      config = build_config(project_dir)
      pr = described_class.new(config)
      results = [
        GemXray::Result.new(
          gem_name: "net-imap",
          gemfile_line: 5,
          gemfile_end_line: 5,
          reasons: [GemXray::Result::Reason.new(type: :unused, detail: "unused", severity: :danger)],
          severity: :danger
        )
      ]

      allow(Time).to receive(:now).and_return(Time.new(2026, 3, 27, 12, 0, 0))
      allow(pr).to receive(:run!) do |*args|
        case args
        when ["git", "rev-parse", "--git-dir"], ["git", "status", "--short"], ["git", "switch", "main"],
          ["git", "switch", "-c", "gemxray/cleanup-20260327"], ["git", "push", "-u", "origin", "gemxray/cleanup-20260327"]
          ""
        when ["git", "status", "--short", "Gemfile.lock"]
          " M Gemfile.lock\n"
        when ["git", "add", "Gemfile"], ["git", "add", "Gemfile.lock"]
          ""
        when ["git", "commit", "-m", "chore: remove net-imap from Gemfile"],
          ["git", "commit", "-m", "chore: refresh Gemfile.lock after gem sweep"]
          ""
        when Array
          if args[0, 3] == ["gh", "pr", "create"]
            "https://example.test/pr/1\n"
          else
            raise "unexpected command: #{args.inspect}"
          end
        end
      end

      editor = instance_double(
        GemXray::Editors::GemfileEditor,
        apply: GemXray::Editors::GemfileEditor::EditResult.new(
          removed: ["net-imap"],
          skipped: [],
          dry_run: false,
          backup_path: nil
        ),
        bundle_install!: "bundle install output"
      )
      allow(GemXray::Editors::GemfileEditor).to receive(:new).and_return(editor)

      pr.create(results)

      expect(editor).to have_received(:bundle_install!)
    end
  end

  it "pushes the branch before falling back to the GitHub API" do
    with_project(sample_project_files) do |project_dir|
      config = build_config(project_dir)
      pr = described_class.new(config)
      results = [
        GemXray::Result.new(
          gem_name: "net-imap",
          gemfile_line: 5,
          gemfile_end_line: 5,
          reasons: [GemXray::Result::Reason.new(type: :unused, detail: "unused", severity: :danger)],
          severity: :danger
        )
      ]

      client = instance_double(GemXray::Editors::GithubApiClient, create_pull_request: "https://example.test/pr/1")

      allow(Time).to receive(:now).and_return(Time.new(2026, 3, 26, 12, 0, 0))
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GH_TOKEN").and_return("token")
      allow(ENV).to receive(:[]).with("GITHUB_TOKEN").and_return(nil)
      allow(ENV).to receive(:[]).with("GITHUB_REPOSITORY").and_return("ydah/gemxray")

      allow(pr).to receive(:run!) do |*args|
        if args == ["git", "rev-parse", "--git-dir"]
          ".git\n"
        elsif args == ["git", "status", "--short"]
          ""
        elsif args == ["git", "switch", "main"]
          ""
        elsif args == ["git", "switch", "-c", "gemxray/cleanup-20260326"]
          ""
        elsif args == ["git", "add", "Gemfile"]
          ""
        elsif args == ["git", "commit", "-m", "chore: remove net-imap from Gemfile"]
          ""
        elsif args == ["git", "push", "-u", "origin", "gemxray/cleanup-20260326"]
          ""
        elsif args[0, 3] == ["gh", "pr", "create"]
          raise GemXray::Error, "gh failed"
        else
          raise "unexpected command: #{args.inspect}"
        end
      end

      stub_const("GemXray::Editors::GithubApiClient", class_double(GemXray::Editors::GithubApiClient, new: client))
      editor = instance_double(
        GemXray::Editors::GemfileEditor,
        apply: GemXray::Editors::GemfileEditor::EditResult.new(
          removed: ["net-imap"],
          skipped: [],
          dry_run: false,
          backup_path: nil
        )
      )
      allow(GemXray::Editors::GemfileEditor).to receive(:new).and_return(editor)

      outcome = pr.create(results, bundle_install: false)

      expect(outcome[:branch]).to eq("gemxray/cleanup-20260326")
      expect(outcome[:pr_url]).to eq("https://example.test/pr/1")
      expect(client).to have_received(:create_pull_request)
    end
  end

  it "creates one branch and PR per gem when per_gem is enabled" do
    with_project(sample_project_files) do |project_dir|
      config = build_config(project_dir)
      pr = described_class.new(config)
      results = %w[net-imap awesome_print].map.with_index(1) do |gem_name, line_number|
        GemXray::Result.new(
          gem_name: gem_name,
          gemfile_line: line_number,
          gemfile_end_line: line_number,
          reasons: [GemXray::Result::Reason.new(type: :unused, detail: "unused", severity: :danger)],
          severity: :danger
        )
      end

      allow(Time).to receive(:now).and_return(Time.new(2026, 3, 26, 12, 0, 0))
      editor = instance_double(GemXray::Editors::GemfileEditor)
      allow(GemXray::Editors::GemfileEditor).to receive(:new).and_return(editor)
      allow(editor).to receive(:apply) do |items, **|
        removed = items.map(&:gem_name)
        GemXray::Editors::GemfileEditor::EditResult.new(
          removed: removed,
          skipped: [],
          dry_run: false,
          backup_path: nil
        )
      end

      allow(pr).to receive(:run!) do |*args|
        case args
        when ["git", "rev-parse", "--git-dir"], ["git", "status", "--short"], ["git", "switch", "main"],
          ["git", "add", "Gemfile"]
          ""
        when ["git", "switch", "-c", "gemxray/cleanup-20260326-net-imap"],
          ["git", "switch", "-c", "gemxray/cleanup-20260326-awesome-print"]
          ""
        when ["git", "commit", "-m", "chore: remove net-imap from Gemfile"],
          ["git", "commit", "-m", "chore: remove awesome_print from Gemfile"]
          ""
        when ["git", "push", "-u", "origin", "gemxray/cleanup-20260326-net-imap"],
          ["git", "push", "-u", "origin", "gemxray/cleanup-20260326-awesome-print"]
          ""
        when ["gh", "pr", "create", "--base", "main", "--head", "gemxray/cleanup-20260326-net-imap", "--title",
          "chore: gemxray cleanup", "--body", kind_of(String), "--label", "dependencies", "--label", "cleanup"],
          ["gh", "pr", "create", "--base", "main", "--head", "gemxray/cleanup-20260326-awesome-print", "--title",
          "chore: gemxray cleanup", "--body", kind_of(String), "--label", "dependencies", "--label", "cleanup"]
          ""
        else
          if args[0, 3] == ["gh", "pr", "create"]
            "https://example.test/#{args[5]}\n"
          else
            raise "unexpected command: #{args.inspect}"
          end
        end
      end

      outcome = pr.create(results, per_gem: true, bundle_install: false)

      expect(outcome[:pull_requests].map { |item| item[:gem_name] }).to eq(%w[net-imap awesome_print])
      expect(outcome[:pull_requests].map { |item| item[:branch] }).to eq(
        %w[gemxray/cleanup-20260326-net-imap gemxray/cleanup-20260326-awesome-print]
      )
    end
  end

  it "falls back to the GitHub API when gh is unavailable" do
    with_project(sample_project_files) do |project_dir|
      config = build_config(project_dir)
      pr = described_class.new(config)
      results = [
        GemXray::Result.new(
          gem_name: "net-imap",
          gemfile_line: 5,
          gemfile_end_line: 5,
          reasons: [GemXray::Result::Reason.new(type: :unused, detail: "unused", severity: :danger)],
          severity: :danger
        )
      ]

      client = instance_double(GemXray::Editors::GithubApiClient, create_pull_request: "https://example.test/pr/1")

      allow(Time).to receive(:now).and_return(Time.new(2026, 3, 26, 12, 0, 0))
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GH_TOKEN").and_return("token")
      allow(ENV).to receive(:[]).with("GITHUB_TOKEN").and_return(nil)
      allow(ENV).to receive(:[]).with("GITHUB_REPOSITORY").and_return("ydah/gemxray")

      allow(pr).to receive(:run!) do |*args|
        if args == ["git", "rev-parse", "--git-dir"]
          ".git\n"
        elsif args == ["git", "status", "--short"]
          ""
        elsif args == ["git", "switch", "main"]
          ""
        elsif args[0, 3] == ["git", "switch", "-c"] && args[3].start_with?("gemxray/cleanup-")
          ""
        elsif args == ["git", "add", "Gemfile"]
          ""
        elsif args == ["git", "commit", "-m", "chore: remove net-imap from Gemfile"]
          ""
        elsif args == ["git", "push", "-u", "origin", "gemxray/cleanup-20260326"]
          ""
        elsif args[0, 3] == ["gh", "pr", "create"]
          raise GemXray::Error, "gh failed"
        else
          raise "unexpected command: #{args.inspect}"
        end
      end

      stub_const("GemXray::Editors::GithubApiClient", class_double(GemXray::Editors::GithubApiClient, new: client))
      editor = instance_double(
        GemXray::Editors::GemfileEditor,
        apply: GemXray::Editors::GemfileEditor::EditResult.new(
          removed: ["net-imap"],
          skipped: [],
          dry_run: false,
          backup_path: nil
        )
      )
      allow(GemXray::Editors::GemfileEditor).to receive(:new).and_return(editor)

      outcome = pr.create(results, bundle_install: false)

      expect(outcome[:pr_url]).to eq("https://example.test/pr/1")
      expect(outcome[:pull_requests].length).to eq(1)
      expect(client).to have_received(:create_pull_request)
    end
  end
end
