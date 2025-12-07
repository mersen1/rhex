# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::PointyToppedGrid) do
  let(:hex_size) { 3 }

  describe "#initialize" do
    it "decorates hexes with pointy topped decorators" do
      hexes = [Rhex::AxialHex.new(0, 0)]

      grid = described_class.new(hexes, hex_size: hex_size)

      expect(grid.to_a.first).to(be_a(Rhex::Decorators::PointyToppedHex))
      expect(grid.hex_size).to(eq(hex_size))
    end
  end

  describe "#pointy_topped?" do
    it "returns true" do
      grid = described_class.new(hex_size: hex_size)

      expect(grid.pointy_topped?).to(be(true))
    end
  end
end
