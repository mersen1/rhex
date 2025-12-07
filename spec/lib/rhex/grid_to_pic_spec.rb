# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::GridToPic) do
  include GridHelpers

  describe "#call" do
    let(:hex_grid) { grid(0) }
    let(:gc) do
      instance_double(
        Magick::Draw,
        text_align: nil,
        translate: nil,
        fill: nil,
        stroke: nil,
        polygon: nil,
        font_size: nil,
        text: nil,
        draw: nil
      )
    end
    let(:imgl) { instance_double(Magick::ImageList, new_image: nil, write: nil) }
    let(:hatch_fill) { instance_double(Magick::HatchFill) }

    before do
      allow(Magick::Draw).to(receive(:new).and_return(gc))
      allow(Magick::ImageList).to(receive(:new).and_return(imgl))
      allow(Magick::HatchFill).to(receive(:new).and_return(hatch_fill))
      stub_const("Magick::CenterAlign", :center) unless defined?(Magick::CenterAlign)
    end

    it "draws each hex and saves the image" do
      expect(gc).to(receive(:translate).with(kind_of(Numeric), kind_of(Numeric)))
      expect(gc).to(receive(:draw).with(imgl))
      expect(imgl).to(receive(:write).with(Rhex.root.join("images", "example.png")))

      described_class.new(hex_grid, hex_size: 2).call("example")
    end

    context "when a font path is configured" do
      let(:font_path) { "/tmp/custom_font.ttf" }

      before do
        allow(File).to(receive(:exist?).and_call_original)
        allow(File).to(receive(:exist?).with(font_path).and_return(true))
        Rhex.configure { |config| config.font_path = font_path }
      end

      after do
        Rhex.configure { |config| config.font_path = nil }
      end

      it "sets the font on the draw context" do
        expect(gc).to(receive(:font=).with(font_path))

        described_class.new(hex_grid, hex_size: 2).call("example")
      end
    end
  end
end
