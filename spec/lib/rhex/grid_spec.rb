# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::Grid) do
  let(:hex_a) { Rhex::AxialHex.new(0, 0) }
  let(:hex_b) { Rhex::AxialHex.new(1, 0, data: :payload) }

  describe ".[]" do
    it "builds a grid with the provided hexes" do
      grid = described_class[hex_a, hex_b]

      expect(grid.to_a).to(contain_exactly(hex_a, hex_b))
    end
  end

  describe "#add" do
    it "stores the hex by q/r coordinates and returns self" do
      grid = described_class.new

      expect(grid.add(hex_a)).to(be(grid))
      expect(grid.include?(Rhex::AxialHex.new(0, 0))).to(be(true))
    end

    it "overwrites an existing coordinate with the latest hex" do
      grid = described_class.new([hex_a])

      grid.add(Rhex::AxialHex.new(0, 0, data: :other))

      expect(grid.to_a.map(&:data)).to(contain_exactly(:other))
    end
  end

  describe "#each" do
    it "returns an enumerator when no block is given" do
      grid = described_class.new([hex_a, hex_b])

      enum = grid.each

      expect(enum).to(be_an(Enumerator))
      expect(enum.to_a).to(contain_exactly(hex_a, hex_b))
    end

    it "yields every hex and returns self" do
      grid = described_class.new([hex_a])
      yielded = []

      expect(grid.each { yielded << _1 }).to(be(grid))
      expect(yielded).to(eq([hex_a]))
    end
  end

  describe "#merge" do
    it "merges another grid" do
      base = described_class.new([hex_a])
      other = described_class.new([hex_b])

      base.merge(other)

      expect(base.to_a).to(contain_exactly(hex_a, hex_b))
    end

    it "merges an enumerable of hexes" do
      grid = described_class.new([hex_a])

      grid.merge([hex_b])

      expect(grid.to_a).to(contain_exactly(hex_a, hex_b))
    end
  end

  describe "#include?" do
    it "looks up by coordinates" do
      grid = described_class.new([hex_a])
      duplicate_coords = Rhex::AxialHex.new(hex_a.q, hex_a.r, data: :different)

      expect(grid.include?(duplicate_coords)).to(be(true))
      expect(grid.exclude?(hex_b)).to(be(true))
    end
  end

  describe "#size" do
    it "returns the number of unique coordinates" do
      grid = described_class.new([hex_a, Rhex::AxialHex.new(0, 0), hex_b])

      expect(grid.size).to(eq(2))
      expect(grid.length).to(eq(2))
    end
  end

  describe "#to_a" do
    it "returns the stored hexes" do
      grid = described_class.new([hex_a, hex_b])

      expect(grid.to_a).to(contain_exactly(hex_a, hex_b))
    end
  end

  describe "#to_pic" do
    it "delegates drawing to GridToPic" do
      grid = described_class.new([hex_a])
      grid_to_pic = instance_double(Rhex::GridToPic, call: true)
      expect(Rhex::GridToPic)
        .to(receive(:new).with(grid, hex_size: Rhex::GridToPic::DEFAULT_HEX_SIZE,
          orientation: Rhex::GridToPic::DEFAULT_ORIENTATION)
        .and_return(grid_to_pic))

      grid.to_pic("file")
    end
  end

  describe "#to_grid" do
    it "returns self when already the target class" do
      grid = described_class.new([hex_a])

      expect(grid.to_grid).to(be(grid))
    end

    it "builds another grid class with the same hexes" do
      custom_class = Class.new(Rhex::Grid)
      grid = described_class.new([hex_a, hex_b])

      converted = grid.to_grid(custom_class)

      expect(converted).to(be_a(custom_class))
      expect(converted.to_a).to(contain_exactly(hex_a, hex_b))
    end
  end
end

RSpec.describe(Enumerable) do
  describe "#to_grid" do
    it "constructs a grid from an enumerable" do
      collection = [Rhex::AxialHex.new(0, 0), Rhex::AxialHex.new(1, 0)]

      grid = collection.to_grid

      expect(grid).to(be_a(Rhex::Grid))
      expect(grid.size).to(eq(2))
    end
  end
end
