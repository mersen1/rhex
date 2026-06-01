# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::DfsPath) do
  include AxialHexHelpers
  include GridHelpers

  let(:grid_algorithms) { Rhex::GridAlgorithms::INSTANCE }

  describe "#call" do
    it "returns the shortest path even when traversing depth-first" do
      grid = grid(3)
      source = Rhex::AxialHex.new(0, 3)
      target = Rhex::AxialHex.new(0, -3)

      dfs_path = described_class.new(grid_hash(grid), grid_algorithms: grid_algorithms).call(source, target)
      bfs_path = Rhex::BfsPath.new(grid_hash(grid), grid_algorithms: grid_algorithms).call(source, target)

      expected_bfs_path =
        coords_to_hexes([[0, 3], [0, 2], [0, 1], [0, 0], [0, -1], [0, -2], [0, -3]])

      expect(bfs_path).to(eq(expected_bfs_path))
      expect(dfs_path.first).to(eq(source))
      expect(dfs_path.last).to(eq(target))
      expect(dfs_path.each_cons(2).all? { |a, b| a.distance(b) == 1 }).to(be(true))
      expect(dfs_path.all? { |hex| grid.include?(hex) }).to(be(true))
      expect(bfs_path.each_cons(2).all? { |a, b| a.distance(b) == 1 }).to(be(true))

      image_configs_path = Rhex.root.join("spec", "fixtures", "image_configs")
      Rhex::ImageConfigs.load!(image_configs_path)

      # Use hexes from grid to ensure we have the correct objects
      dfs_path_hexes = dfs_path.map { |hex| grid.fetch(hex) }
      dfs_path_hexes.each { |hex| hex.image_config ||= Rhex::ImageConfigs.image_config_for(:path) }

      source_hex = grid.fetch(source)
      target_hex = grid.fetch(target)
      source_hex.image_config = Rhex::ImageConfigs.image_config_for(:source)
      target_hex.image_config = Rhex::ImageConfigs.image_config_for(:target)

      grid.merge(dfs_path_hexes).merge([source_hex, target_hex])
        .to_pic("dfs_path", orientation: :pointy_topped, path: dfs_path_hexes)
    end

    context "when obstacles are defined" do
      before do
        image_configs_path = Rhex.root.join("spec", "fixtures", "image_configs")
        Rhex::ImageConfigs.load!(image_configs_path)
      end

      it "avoids obstacles with a deterministic path" do
        grid = grid(3)
        source = Rhex::AxialHex.new(0, 0)
        target = Rhex::AxialHex.new(2, -1)
        obstacles = coords_to_hexes([[1, 0], [1, -1]], image_config: Rhex::ImageConfigs.image_config_for(:obstacle))

        path = described_class.new(grid_hash(grid), obstacles: obstacles, grid_algorithms: grid_algorithms).call(
          source, target
        )

        # Use hexes from grid to ensure we have the correct objects
        path_hexes = path.map { |hex| grid.fetch(hex) }
        path_hexes.each { |hex| hex.image_config ||= Rhex::ImageConfigs.image_config_for(:path) }

        source_hex = grid.fetch(source)
        target_hex = grid.fetch(target)
        source_hex.image_config = Rhex::ImageConfigs.image_config_for(:source)
        target_hex.image_config = Rhex::ImageConfigs.image_config_for(:target)

        grid.merge(obstacles)
          .merge(path_hexes)
          .merge([source_hex, target_hex])
          .to_pic("dfs_path_obstacles", orientation: :pointy_topped, path: path_hexes)

        expect(path.first).to(eq(source))
        expect(path.last).to(eq(target))
        expect(path & obstacles).to(be_empty)
        expect(path.each_cons(2).all? { |a, b| a.distance(b) == 1 }).to(be(true))
        expect(path.all? { |hex| grid.include?(hex) }).to(be(true))
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
