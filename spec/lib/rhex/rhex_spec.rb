# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex) do
  describe ".root" do
    it "returns the gem root path" do
      expect(described_class.root).to(be_a(Pathname))
      expect(File).to(exist(described_class.root.join("lib", "rhex.rb")))
    end
  end

  describe "font configuration" do
    after do
      described_class.configure { |config| config.font_path = nil }
      ENV.delete("RHEX_FONT")
    end

    it "allows setting font_path through configure" do
      allow(File).to(receive(:exist?).and_call_original)
      allow(File).to(receive(:exist?).with("/tmp/custom.ttf").and_return(true))
      described_class.configure { |config| config.font_path = "/tmp/custom.ttf" }

      expect(described_class.font_path).to(eq("/tmp/custom.ttf"))
    end

    it "falls back to RHEX_FONT when not configured" do
      allow(File).to(receive(:exist?).and_call_original)
      allow(File).to(receive(:exist?).with("/env/font.ttf").and_return(true))
      ENV["RHEX_FONT"] = "/env/font.ttf"

      expect(described_class.font_path).to(eq("/env/font.ttf"))
    end

    it "raises when configured font does not exist" do
      expect do
        described_class.configure { |config| config.font_path = "/missing.ttf" }
      end.to(raise_error(ArgumentError, /missing font file/))
    end

    it "raises when ENV font does not exist" do
      ENV["RHEX_FONT"] = "/missing_env.ttf"

      expect { described_class.font_path }.to(raise_error(ArgumentError, /missing font file/))
    end

    it "reports configured when set via configure" do
      allow(File).to(receive(:exist?).with("/tmp/custom.ttf").and_return(true))
      described_class.configure { |config| config.font_path = "/tmp/custom.ttf" }

      expect(described_class.font_path_configured?).to(eq(true))
    end

    it "reports configured when ENV is set" do
      allow(File).to(receive(:exist?).with("/env/font.ttf").and_return(true))
      ENV["RHEX_FONT"] = "/env/font.ttf"

      expect(described_class.font_path_configured?).to(eq(true))
    end

    it "reports not configured when neither ENV nor configure is set" do
      expect(described_class.font_path_configured?).to(eq(false))
    end
  end
end
