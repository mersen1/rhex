# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::FlatToppedGrid) do
  let(:hex_size) { 4 }
  let(:hexes) { [Rhex::AxialHex.new(0, 0), Rhex::AxialHex.new(1, -1)] }

  describe "#initialize" do
    it "decorates provided hexes with the configured size" do
      grid = described_class.new(hexes, hex_size: hex_size)

      expect(grid.size).to(eq(2))
      expect(grid.to_a).to(all(be_a(Rhex::Decorators::FlatToppedHex)))
      expect(grid.hex_size).to(eq(hex_size))
    end
  end

  describe "#add" do
    it "wraps added hexes in a decorator" do
      grid = described_class.new(hex_size: hex_size)
      hex = Rhex::AxialHex.new(2, -2)

      grid.add(hex)

      decorated_hex = grid.to_a.first
      expect(decorated_hex).to(be_a(Rhex::Decorators::FlatToppedHex))
      expect(decorated_hex.size).to(eq(hex_size))
      expect(decorated_hex.q).to(eq(hex.q))
    end
  end

  describe "#pointy_topped?" do
    it "returns false for flat topped grids" do
      grid = described_class.new(hex_size: hex_size)

      expect(grid.pointy_topped?).to(be(false))
    end
  end
end
