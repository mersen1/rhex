# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::Decorators::GridWithMarkup) do
  let(:hexes) do
    [
      Rhex::AxialHex.new(-1, 0),
      Rhex::AxialHex.new(3, 2),
      Rhex::AxialHex.new(1, 1),
    ]
  end
  let(:grid) { Rhex::Grid.new(hexes) }
  let(:decorated_grid) { described_class.new(grid) }

  describe "#central_hex" do
    it "returns a hex at the median coordinates" do
      expect(decorated_grid.central_hex).to(eq(Rhex::AxialHex.new(1.0, 1.0)))
    end
  end

  describe "coordinate bounds" do
    it "exposes min/max q and r values" do
      expect(decorated_grid.q_min).to(eq(-1))
      expect(decorated_grid.q_max).to(eq(3))
      expect(decorated_grid.r_min).to(eq(0))
      expect(decorated_grid.r_max).to(eq(2))
    end
  end

  describe "#median" do
    it "supports odd and even arrays" do
      expect(decorated_grid.send(:median, [1, 2, 3])).to(eq(2))
      expect(decorated_grid.send(:median, [0, 2])).to(eq(1.0))
    end
  end
end
