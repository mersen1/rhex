# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::BfsPath) do
  include AxialHexHelpers
  include GridHelpers

  let(:grid_algorithms) { Rhex::GridAlgorithms::INSTANCE }

  describe "#call" do
    it "finds the shortest path on the same grid as DFS for comparison" do
      grid = grid(3)
      source = Rhex::AxialHex.new(0, 3)
      target = Rhex::AxialHex.new(0, -3)

      shortest_path = described_class.new(grid_hash(grid), grid_algorithms: grid_algorithms).call(source, target)

      expected_shortest_path =
        coords_to_hexes([[0, 3], [0, 2], [0, 1], [0, 0], [0, -1], [0, -2], [0, -3]])

      expect(shortest_path).to(eq(expected_shortest_path))

      image_configs_path = Rhex.root.join("spec", "fixtures", "image_configs")
      Rhex::ImageConfigs.load!(image_configs_path)

      # Use hexes from grid to ensure we have the correct objects
      path_hexes = shortest_path.map { |hex| grid.fetch(hex) }
      path_hexes.each { |hex| hex.image_config ||= Rhex::ImageConfigs.image_config_for(:path) }

      source_hex = grid.fetch(source)
      target_hex = grid.fetch(target)
      source_hex.image_config = Rhex::ImageConfigs.image_config_for(:source)
      target_hex.image_config = Rhex::ImageConfigs.image_config_for(:target)

      grid.merge(path_hexes)
        .merge([source_hex, target_hex])
        .to_pic("bfs_path", orientation: :pointy_topped)
    end

    context "when obstacles are defined" do
      before do
        image_configs_path = Rhex.root.join("spec", "fixtures", "image_configs")

        Rhex::ImageConfigs.load!(image_configs_path)
      end

      it "finds the shortest path", aggregate_failure: true do
        grid = grid(3)
        source = Rhex::AxialHex.new(0, 0)
        target = Rhex::AxialHex.new(2, -2)

        obstacles =
          coords_to_hexes([
            [1, 0], [1, -1],
          ], image_config: Rhex::ImageConfigs.image_config_for(:obstacle))

        shortest_path =
          described_class.new(grid_hash(grid), obstacles: obstacles, grid_algorithms: grid_algorithms).call(source,
            target)

        # Use hexes from grid to ensure we have the correct objects
        path_hexes = shortest_path.map { |hex| grid.fetch(hex) }
        path_hexes.each { |hex| hex.image_config ||= Rhex::ImageConfigs.image_config_for(:path) }

        source_hex = grid.fetch(source)
        target_hex = grid.fetch(target)
        source_hex.image_config = Rhex::ImageConfigs.image_config_for(:source)
        target_hex.image_config = Rhex::ImageConfigs.image_config_for(:target)

        grid.merge(obstacles)
          .merge(path_hexes)
          .merge([source_hex, target_hex])
          .to_pic("bfs_path_obstacles", orientation: :pointy_topped)

        expect(shortest_path.first).to(eq(source))
        expect(shortest_path.last).to(eq(target))
        expect(shortest_path & obstacles).to(be_empty)
        expect(shortest_path).to(all(satisfy { |hex| grid.include?(hex) }))
        expect(shortest_path.each_cons(2).all? { |a, b| a.distance(b) == 1 }).to(be(true))
      end
    end

    it "returns only the source when source equals target" do
      grid = grid(1)
      source = Rhex::AxialHex.new(0, 0)

      expect(described_class.new(grid_hash(grid), grid_algorithms: grid_algorithms).call(source,
        source)).to(eq([source]))
    end

    it "returns grid-stored hex instances in the path" do
      grid = grid(2)
      source = grid.fetch(Rhex::AxialHex.new(0, 0))
      target = grid.fetch(Rhex::AxialHex.new(1, 1))

      path = described_class.new(grid_hash(grid), grid_algorithms: grid_algorithms).call(source, target)

      expect(path.first).to(be(source))
      expect(path.last).to(be(target))
      path.each { |hex| expect(grid.fetch(hex)).to(be(hex)) }
    end

    it "raises when no route exists" do
      source = Rhex::AxialHex.new(0, 0)
      target = Rhex::AxialHex.new(3, 0)
      grid = Rhex::Grid.new([source, target])

      expect { described_class.new(grid_hash(grid), grid_algorithms: grid_algorithms).call(source, target) }
        .to(raise_error(Rhex::Grid::PathNotFoundError))
    end

    it "raises when the source is missing from the grid" do
      grid = grid(0)
      source = Rhex::AxialHex.new(1, 0)
      target = Rhex::AxialHex.new(0, 0)

      expect { described_class.new(grid_hash(grid), grid_algorithms: grid_algorithms).call(source, target) }
        .to(raise_error(Rhex::Grid::GridDoesNotContainSourceError))
    end

    it "raises when the target is missing from the grid" do
      grid = grid(0)
      source = Rhex::AxialHex.new(0, 0)
      target = Rhex::AxialHex.new(1, 0)

      expect { described_class.new(grid_hash(grid), grid_algorithms: grid_algorithms).call(source, target) }
        .to(raise_error(Rhex::Grid::GridDoesNotContainTargetError))
    end
  end
end
