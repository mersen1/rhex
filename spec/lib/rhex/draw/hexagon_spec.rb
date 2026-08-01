# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::Draw::Hexagon) do
  let(:hex) { Rhex::Decorators::FlatToppedHex.new(Rhex::AxialHex.new(0, 0), size: 2) }
  let(:gc) do
    instance_double(
      Magick::Draw,
      fill: nil,
      stroke: nil,
      polygon: nil,
      font_size: nil,
      text: nil
    )
  end

  describe "#call" do
    it "draws the hexagon and its label with default config" do
      allow(gc).to(receive(:fill))
      allow(gc).to(receive(:stroke))
      allow(gc).to(receive(:polygon))
      allow(gc).to(receive(:font_size))
      allow(gc).to(receive(:text))

      described_class.new(gc: gc, hex: hex).call

      expect(gc).to(have_received(:polygon)) do |*args|
        expect(args.length).to(eq(12))
      end
      expect(gc).to(have_received(:text).with(hex.coordinates.x, a_kind_of(Numeric), include("0,0")))
    end

    it "does not run the contract when using the cached default config" do
      allow(Rhex::Contracts::ImageConfigContract).to(receive(:new).and_call_original)

      3.times { described_class.new(gc: gc, hex: hex) }

      expect(Rhex::Contracts::ImageConfigContract).not_to(have_received(:new))
    end

    it "still validates an explicitly provided default_image_config" do
      invalid = { hexagon: { color: "#fff" }, text: {} }

      expect do
        described_class.new(gc: gc, hex: hex, default_image_config: invalid)
      end.to(raise_error(ArgumentError))
    end

    it "uses a valid explicitly provided default_image_config" do
      custom_default = {
        hexagon: { color: "#abcdef", stroke_color: "#000000", size: 10 },
        text: { color: "#111111", stroke_color: "#222222", font_size: 8 },
      }
      allow(gc).to(receive(:fill))
      allow(gc).to(receive(:stroke))
      allow(gc).to(receive(:polygon))
      allow(gc).to(receive(:font_size))
      allow(gc).to(receive(:text))

      described_class.new(gc: gc, hex: hex, default_image_config: custom_default).call

      expect(gc).to(have_received(:font_size).with(8))
    end

    it "draws using custom image config when provided" do
      custom_config = {
        hexagon: { color: "#fff", stroke_color: "#000" },
        text: { color: "#123", stroke_color: "#321", font_size: 10 },
      }

      hex.image_config = custom_config
      allow(gc).to(receive(:fill))
      allow(gc).to(receive(:stroke))
      allow(gc).to(receive(:polygon))
      allow(gc).to(receive(:font_size))
      allow(gc).to(receive(:text))

      described_class.new(gc: gc, hex: hex).call

      expect(gc).to(have_received(:fill).with("#fff").at_least(:once))
      expect(gc).to(have_received(:font_size).with(10))
    end
  end
end
