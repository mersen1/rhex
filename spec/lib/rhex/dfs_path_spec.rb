# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::DfsPath) do
  include AxialHexHelpers
  include GridHelpers

  describe "#call" do
    it "finds a path depth-first" do
      grid = grid(2)
      source = Rhex::AxialHex.new(0, 2)
      target = Rhex::AxialHex.new(1, -1)

      path = described_class.new(grid).call(source, target)

      expect(path.first).to(eq(source))
      expect(path.last).to(eq(target))
      expect(path).not_to(be_empty)
      expect(path.each_cons(2).all? { |a, b| a.distance(b) == 1 }).to(be(true))
    end

    context "when obstacles are defined" do
      it "avoids obstacles" do
        grid = grid(3)
        source = Rhex::AxialHex.new(0, 0)
        target = Rhex::AxialHex.new(2, -1)
        obstacles = coords_to_hexes([[1, 0], [1, -1]])

        path = described_class.new(grid, obstacles: obstacles).call(source, target)

        grid.merge(obstacles)
          .merge(path)
          .to_pic("dfs_path", orientation: :pointy_topped)

        expect(path.first).to(eq(source))
        expect(path.last).to(eq(target))
        expect(path & obstacles).to(be_empty)
        expect(path.each_cons(2).all? { |a, b| a.distance(b) == 1 }).to(be(true))
      end
    end

    it "returns only the source when source equals target" do
      grid = grid(1)
      source = Rhex::AxialHex.new(0, 0)

      expect(described_class.new(grid).call(source, source)).to(eq([source]))
    end

    it "returns an empty path when no route exists" do
      source = Rhex::AxialHex.new(0, 0)
      target = Rhex::AxialHex.new(3, 0)
      grid = Rhex::Grid.new([source, target])

      expect(described_class.new(grid).call(source, target)).to(eq([]))
    end

    it "raises when the source is missing from the grid" do
      grid = grid(0)
      source = Rhex::AxialHex.new(1, 0)
      target = Rhex::AxialHex.new(0, 0)

      expect { described_class.new(grid).call(source, target) }
        .to(raise_error(described_class::GridDoesNotContainSourceError))
    end

    it "raises when the target is missing from the grid" do
      grid = grid(0)
      source = Rhex::AxialHex.new(0, 0)
      target = Rhex::AxialHex.new(1, 0)

      expect { described_class.new(grid).call(source, target) }
        .to(raise_error(described_class::GridDoesNotContainTargetError))
    end
  end
end
