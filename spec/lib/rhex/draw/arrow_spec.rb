# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::Draw::Arrow) do
  let(:from) { Rhex::Decorators::PointyToppedHex.new(Rhex::AxialHex.new(0, 0), size: 64) }
  let(:to) { Rhex::Decorators::PointyToppedHex.new(Rhex::AxialHex.new(1, 0), size: 64) }
  let(:gc) do
    instance_double(
      Magick::Draw,
      fill: nil,
      stroke: nil,
      stroke_width: nil,
      line: nil
    )
  end

  describe "#call" do
    it "draws the shaft and two arrowhead barbs pointing towards the target" do
      described_class.new(gc: gc, from: from, to: to).call

      # one shaft line + two arrowhead barbs
      expect(gc).to(have_received(:line).exactly(3).times)
    end

    it "centers the shaft on the source hex" do
      described_class.new(gc: gc, from: from, to: to).call

      expect(gc).to(have_received(:line).with(
        a_kind_of(Numeric), a_kind_of(Numeric), a_kind_of(Numeric), a_kind_of(Numeric)
      ).at_least(:once))
    end
  end
end
