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
    let(:bundled_font) { described_class.root.join("fonts", "Inconsolata-Regular.ttf").to_s }

    before do
      @original_font_path = described_class.font_path
    end

    after do
      described_class.font_path = @original_font_path
    end

    it "returns the bundled font path by default" do
      expect(described_class.font_path).to(eq(bundled_font))
    end

    it "allows overriding font path via configure" do
      described_class.configure { |config| config.font_path = "/tmp/custom.ttf" }

      expect(described_class.font_path).to(eq("/tmp/custom.ttf"))
    end

    it "coerces assigned font paths to strings" do
      described_class.font_path = Pathname.new("/tmp/custom_path.ttf")

      expect(described_class.font_path).to(eq("/tmp/custom_path.ttf"))
    end

    it "yields the Rhex module to configure blocks" do
      expect { |blk| described_class.configure(&blk) }.to(yield_with_args(described_class))
    end
  end
end
