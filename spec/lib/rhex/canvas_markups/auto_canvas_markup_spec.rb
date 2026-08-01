# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::CanvasMarkups::AutoCanvasMarkup) do
  let(:hex_size) { 2 }
  let(:grid) { Rhex::FlatToppedGrid.new([Rhex::AxialHex.new(0, 0), Rhex::AxialHex.new(1, 1)], hex_size: hex_size) }
  let(:markup) { described_class.new(grid) }

  describe "#width and #height" do
    it "scale with the number of columns and rows" do
      expect(markup.width).to(eq(8))
      expect(markup.height).to(eq(10))
      expect(markup.cols).to(eq(markup.width))
      expect(markup.rows).to(eq(markup.height))
    end
  end

  describe "#center" do
    it "centers the grid within the canvas" do
      center = markup.center

      expect(center.x).to(eq(2.5))
      expect(center.y).to(be_within(1e-6).of(2.401923788646684))
      expect(markup.center).to(be(center))
    end
  end
end
