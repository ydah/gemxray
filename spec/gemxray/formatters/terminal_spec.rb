# frozen_string_literal: true

RSpec.describe GemXray::Formatters::Terminal do
  it "renders grouped reasons in a tree-style report" do
    report = GemXray::Report.new(
      version: GemXray::VERSION,
      ruby_version: "3.2.2",
      rails_version: "7.1.3",
      scanned_at: Time.now.iso8601,
      results: [
        GemXray::Result.new(
          gem_name: "net-imap",
          severity: :danger,
          reasons: [
            GemXray::Result::Reason.new(type: :unused, detail: "unused", severity: :danger),
            GemXray::Result::Reason.new(type: :redundant, detail: "via mail", severity: :warning)
          ]
        )
      ]
    )

    output = described_class.new.render(report)

    expect(output).to include("🧹 gemxray scan results")
    expect(output).to include("[DANGER] net-imap")
    expect(output).to include("├─ unused")
    expect(output).to include("└─ via mail")
    expect(output).to include("検出: 1件")
  end

  it "renders pinned redundant notes as additional tree lines" do
    report = GemXray::Report.new(
      version: GemXray::VERSION,
      ruby_version: "3.2.2",
      rails_version: "7.1.3",
      scanned_at: Time.now.iso8601,
      results: [
        GemXray::Result.new(
          gem_name: "puma",
          severity: :info,
          reasons: [
            GemXray::Result::Reason.new(type: :redundant, detail: "already installed as a dependency of rails", severity: :info),
            GemXray::Result::Reason.new(
              type: :redundant,
              detail: "version is pinned in Gemfile (~> 6.0), so this may be intentional",
              severity: :info
            )
          ]
        )
      ]
    )

    output = described_class.new.render(report)

    expect(output).to include("[INFO] puma (redundant)")
    expect(output).to include("└─ version is pinned in Gemfile (~> 6.0), so this may be intentional")
  end
end
