# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::BfsPath) do
  include AxialHexHelpers
  include GridHelpers

  describe "#call" do
    it "finds the shortest path" do
      grid = grid(2)
      source = Rhex::AxialHex.new(0, 2)
      target = Rhex::AxialHex.new(0, -2)

      shortest_path = described_class.new(grid).call(source, target)

      expect(shortest_path)
        .to(contain_exactly(
          source,
          Rhex::AxialHex.new(0, 1),
          Rhex::AxialHex.new(0, 0),
          Rhex::AxialHex.new(0, -1),
          target
        ))
    end

    context "when obstacles are defined" do
      before do
        image_configs_path = Rhex.root.join("spec", "fixtures", "image_configs")

        Rhex::ImageConfigs.load!(image_configs_path)
      end

      it "finds the shortest path", aggregate_failure: true do
        grid = grid(5)
        source = Rhex::AxialHex.new(1, 1)
        target = Rhex::AxialHex.new(-5, 5)

        obstacles =
          coords_to_hexes([
            [1, -1], [2, -1], [2, 0], [2, 1], [1, 2], [0, 2], [-1, 2], [-1, 1],
            [-2, 1], [-1, -1], [0, -2], [1, -3], [-3, 2], [-4, 3], [-5, 4],
          ], image_config: Rhex::ImageConfigs.obstacle_image_config)

        shortest_path = described_class.new(grid, obstacles: obstacles).call(source, target)

        expected_shortest_path =
          coords_to_hexes([
            [1, 1], [1, 0], [0, 0], [0, -1], [1, -2], [2, -2], [3, -2], [3, -1], [3, 0],
            [3, 1], [2, 2], [1, 3], [0, 3], [-1, 3], [-2, 3], [-3, 4], [-4, 5], [-5, 5],
          ], image_config: Rhex::ImageConfigs.path_image_config)

        grid.merge(obstacles)
          .merge(expected_shortest_path)
          .to_pic("bfs_path", orientation: :pointy_topped)

        expect(shortest_path.first).to(eq(source))
        expect(shortest_path.last).to(eq(target))
        expect(shortest_path.size).to(eq(expected_shortest_path.size))
        expect(shortest_path & obstacles).to(be_empty)
        expect(shortest_path).to(all(satisfy { |hex| grid.include?(hex) }))
        expect(shortest_path.each_cons(2).all? { |a, b| a.distance(b) == 1 }).to(be(true))
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
