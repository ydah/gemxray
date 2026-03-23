# frozen_string_literal: true

RSpec.describe GemXray::Editors::GithubPr do
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

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GH_TOKEN").and_return("token")
      allow(ENV).to receive(:[]).with("GITHUB_TOKEN").and_return(nil)
      allow(ENV).to receive(:[]).with("GITHUB_REPOSITORY").and_return("ydah/gemxray")

      allow(pr).to receive(:run!) do |*args|
        if args == ["git", "rev-parse", "--git-dir"]
          ".git\n"
        elsif args == ["git", "status", "--short"]
          ""
        elsif args[0, 3] == ["git", "switch", "-c"] && args[3].start_with?("gemxray/cleanup-")
          ""
        elsif args == ["git", "add", "Gemfile"]
          ""
        elsif args == ["git", "commit", "-m", "chore: remove net-imap from Gemfile"]
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

      outcome = pr.create(results)

      expect(outcome[:pr_url]).to eq("https://example.test/pr/1")
      expect(client).to have_received(:create_pull_request)
    end
  end
end
