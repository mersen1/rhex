# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::CubeHex) do
  include GridHelpers
  include AxialHexHelpers

  before do
    image_configs_path = Rhex.root.join("spec", "fixtures", "image_configs")

    Rhex::ImageConfigs.load!(image_configs_path)
  end

  describe "#spiral_ring" do
    it "returns a spiral list of hexagons" do
      center = Rhex::AxialHex.new(-1, -1)

      spiral_ring = center.spiral_ring(2)

      spiral_ring.to_grid.to_pic("spiral_ring", orientation: Rhex::GridToPic::POINTY_TOPPED)

      expect(spiral_ring.length).to(eq(19))
    end
  end

  describe "#ring" do
    it "returns a ring list of hexagons" do
      center = Rhex::AxialHex.new(0, 0)

      ring = center.ring(2)

      ring.to_grid.to_pic("ring")

      expect(ring.length).to(eq(12))
    end
  end

  describe "#linedraw" do
    it "returns straight path to the target" do
      source = Rhex::CubeHex.new(-4, 0, 4)
      target = Rhex::CubeHex.new(-1, -1, 2)

      expect(source.linedraw(target))
        .to(contain_exactly(
          source,
          Rhex::CubeHex.new(-3, 0, 3),
          Rhex::CubeHex.new(-2, -1, 3),
          target
        ))
    end
  end

  describe "#neighbors" do
    context "when `grid` is defined" do
      it "returns neighbors according to the grid" do
        grid = grid(2)
        center = Rhex::AxialHex.new(0, 2)
        center.image_config = Rhex::ImageConfigs.source_image_config

        expected_neighbors = coords_to_hexes(
          [[1, 1], [0, 1], [-1, 2]],
          image_config: Rhex::ImageConfigs.path_image_config
        )

        grid
          .merge(expected_neighbors)
          .merge([center])
          .to_pic("neighbors_inside_grid")

        expect(center.neighbors(grid: grid)).to(contain_exactly(*expected_neighbors))
      end
    end

    context "when grid is not defined" do
      it "returns all 6 neighbors" do
        center = Rhex::AxialHex.new(0, -2)

        center.neighbors.to_grid.to_pic("neighbors")

        expect(center.neighbors)
          .to(contain_exactly(
            Rhex::CubeHex.new(0, -3, 3),
            Rhex::CubeHex.new(1, -3, 2),
            Rhex::CubeHex.new(1, -2, 1),
            Rhex::CubeHex.new(0, -1, 1),
            Rhex::CubeHex.new(-1, -1, 2),
            Rhex::CubeHex.new(-1, -2, 3)
          ))
      end
    end
  end

  describe "#field_of_view" do
    it "calculate field of view" do
      grid = grid(3)
      source = Rhex::AxialHex.new(-1, 2, image_config: Rhex::ImageConfigs.source_image_config)
      obstacles = coords_to_hexes(
        [[-1, 1], [-1, 0], [0, -1], [1, -1], [1, 0]],
        image_config: Rhex::ImageConfigs.obstacle_image_config
      )

      expect_field_of_view = coords_to_hexes(
        [[0, 0], [0, 1], [1, 1], [0, 2], [-1, 3], [0, 3], [1, 2], [-3, 0], [-3, 1], [-3, 2], [-3, 3],
         [-2, 1], [-2, 2], [-2, 3], [2, 0], [2, 1], [3, 0], [3, -1],],
        image_config: Rhex::ImageConfigs.path_image_config
      )

      field_of_view = source.field_of_view(grid, obstacles)

      grid.merge(obstacles)
        .merge(expect_field_of_view)
        .merge([source])
        .to_pic("field_of_view")

      expect(field_of_view).to(contain_exactly(*expect_field_of_view))
    end
  end

  describe "#reachable" do
    it "shows reachable hexes" do
      source = Rhex::AxialHex.new(0, 0)
      source.image_config = Rhex::ImageConfigs.source_image_config

      obstacles = coords_to_hexes([
        [1, -1], [2, -1], [2, 0], [2, 1], [1, 2], [0, 2],
        [-1, 2], [-1, 1], [-2, 1], [-1, -1], [0, -2], [1, -3],
      ], image_config: Rhex::ImageConfigs.obstacle_image_config)

      expected_reachable = coords_to_hexes([
        [0, 0], [1, 0], [0, 1], [1, 1], [-1, 0], [0, -1], [1, -2],
        [2, -3], [2, -2], [-2, -1], [-3, 0], [-2, 0], [-3, 1],
      ], image_config: Rhex::ImageConfigs.path_image_config)

      # Build a visually square 8x8 board using even-q offset -> axial mapping
      base_grid =
        (-4..3).flat_map do |col|
          (-4..3).map do |row|
            axial_r = row - (col / 2)
            Rhex::AxialHex.new(col, axial_r)
          end
        end.to_grid

      base_grid
        .merge(obstacles)
        .merge(expected_reachable + [])
        .merge([source])
        .to_pic("reachable", orientation: Rhex::GridToPic::FLAT_TOPPED)

      expect(source.reachable(3, obstacles: obstacles)).to(contain_exactly(*expected_reachable))
    end

    it "includes the source hex in the reachable list" do
      source = Rhex::AxialHex.new(0, 0)

      expect(source.reachable(0)).to(contain_exactly(source))
    end

    it "excludes obstacles from reachable hexes" do
      source = Rhex::AxialHex.new(0, 0)
      obstacles = coords_to_hexes([[1, 0]])

      reachable = source.reachable(1, obstacles: obstacles)

      expect(reachable).not_to(include(Rhex::AxialHex.new(1, 0)))
    end
  end

  describe "#linedraw" do
    module Enumerable
      def to_grid(klass = Rhex::Grid, *args, **kwargs, &)
        klass.new(self, *args, **kwargs, &)
      end
    end

    it "returns straight path to the target" do
      source = Rhex::AxialHex.new(-4, 0)
      target = Rhex::AxialHex.new(4, -2)

      path = source.linedraw(target)
      path.each { _1.image_config = Rhex::ImageConfigs.path_image_config }
      path.to_grid.to_pic("linedraw")

      expect(path)
        .to(contain_exactly(
          source,
          Rhex::AxialHex.new(-3, 0), Rhex::AxialHex.new(-2, 0), Rhex::AxialHex.new(-1, -1), Rhex::AxialHex.new(0, -1),
          Rhex::AxialHex.new(1, -1), Rhex::AxialHex.new(2, -1), Rhex::AxialHex.new(3, -2),
          target
        ))
    end
  end

  describe "#distance" do
    it "calculates the distance between two hexes" do
      from = Rhex::AxialHex.new(0, 2)
      to = Rhex::AxialHex.new(0, -2)
      expect(from.distance(to)).to(eq(4))
    end
  end

  describe "#bfs_shortest_path" do
    it "uses BfsPath" do
      source = Rhex::AxialHex.new(0, 0)
      target = instance_double(Rhex::AxialHex)
      grid = instance_double(Rhex::Grid)
      obstacles = instance_double(Array)

      shortest_path = double
      bfs_path_instance = double

      expect(Rhex::BfsPath)
        .to(receive(:new).with(grid, obstacles: obstacles).and_return(bfs_path_instance))
      expect(bfs_path_instance).to(receive(:call).with(source, target).and_return(shortest_path))

      expect(source.bfs_shortest_path(target, grid, obstacles: obstacles)).to(eq(shortest_path))
    end
  end

  describe "#dfs_path" do
    it "uses DfsPath" do
      source = Rhex::AxialHex.new(0, 0)
      target = instance_double(Rhex::AxialHex)
      grid = instance_double(Rhex::Grid)
      obstacles = instance_double(Array)

      path = double
      dfs_path_instance = double

      expect(Rhex::DfsPath)
        .to(receive(:new).with(grid, obstacles: obstacles).and_return(dfs_path_instance))
      expect(dfs_path_instance).to(receive(:call).with(source, target).and_return(path))

      expect(source.dfs_path(target, grid, obstacles: obstacles)).to(eq(path))
    end
  end

  describe "#to_axial" do
    it "converts cube to axial" do
      cube = described_class.new(0, -1, 1)

      expect(cube.to_axial).to(eq(Rhex::AxialHex.new(0, -1)))
    end
  end

  describe "#==" do
    it "compares coordinates" do
      cube = described_class.new(1, -1, 0)

      expect(cube).to(eq(described_class.new(1, -1, 0)))
      expect(cube).not_to(eq(described_class.new(0, 0, 0)))
      expect(cube.eql?(cube)).to(be(true))
      expect(cube != described_class.new(0, -1, 1)).to(be(true))
      expect(cube.hash).to(eq({ q: 1, r: -1, s: 0 }.hash))
    end
  end

  describe "#reflection" do
    let(:hex) { described_class.new(1, 2, -3) }

    it "reflects across the q axis" do
      expect(hex.reflection_q).to(eq(described_class.new(1, -3, 2)))
    end

    it "reflects across the r axis" do
      expect(hex.reflection_r).to(eq(described_class.new(-3, 2, 1)))
    end

    it "reflects across the s axis" do
      expect(hex.reflection_s).to(eq(described_class.new(2, 1, -3)))
    end
  end

  describe "#neighbor" do
    it "returns nil when outside of the provided grid" do
      grid = instance_double(Rhex::Grid, include?: false)
      hex = described_class.new(0, 0, 0)

      expect(hex.neighbor(0, grid: grid)).to(be_nil)
    end

    it "raises for invalid direction" do
      hex = described_class.new(0, 0, 0)

      expect { hex.neighbor(10) }.to(raise_error(Rhex::CubeHex::NotInTheDirectionVectorsList))
    end
  end

  describe "#spiral_ring" do
    it "raises when radius is zero" do
      hex = described_class.new(0, 0, 0)

      expect { hex.spiral_ring(0) }.to(raise_error(Rhex::CubeHex::RadiusCannotBeZero))
    end
  end

  describe "#round" do
    it "rounds with q component dominating" do
      hex = described_class.new(0.6, 0.2, -0.8)

      expect(hex.send(:round)).to(eq(described_class.new(1, 0, -1)))
    end

    it "rounds with r component dominating" do
      hex = described_class.new(0.2, 0.7, -0.9)

      expect(hex.send(:round)).to(eq(described_class.new(0, 1, -1)))
    end

    it "rounds with s component dominating" do
      hex = described_class.new(0.1, 0.2, -0.3)

      expect(hex.send(:round)).to(eq(described_class.new(0, 0, 0)))
    end
  end
end

RSpec.describe(Rhex::CubeHex::Math) do
  describe ".lerp" do
    it "interpolates between start and stop" do
      expect(described_class.lerp(0, 10, 0.25)).to(eq(2.5))
    end
  end

  describe Rhex::CubeHex::Math::Hexagon do
    it "calculates movement range for a given radius" do
      math = Class.new { include Rhex::CubeHex::Math::Hexagon }.new

      expect(math.movement_range(2)).to(eq(19))
    end
  end
end
