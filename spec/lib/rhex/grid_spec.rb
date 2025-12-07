# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::Grid) do
  include GridHelpers
  include AxialHexHelpers

  let(:hex_a) { Rhex::AxialHex.new(0, 0) }
  let(:hex_b) { Rhex::AxialHex.new(1, 0, data: :payload) }

  before do
    image_configs_path = Rhex.root.join("spec", "fixtures", "image_configs")

    Rhex::ImageConfigs.load!(image_configs_path)
  end

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

    it "keeps right-hand grid values on coordinate collisions" do
      base_hex = Rhex::AxialHex.new(0, 0, data: :base)
      overriding_hex = Rhex::AxialHex.new(0, 0, data: :other)

      base = described_class.new([base_hex])
      other = described_class.new([overriding_hex])

      base.merge(other)

      expect(base.fetch(base_hex).data).to(eq(:other))
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

  describe "#neighbor" do
    it "returns nil when the neighbor is outside of the grid" do
      grid = described_class.new([hex_a])

      expect(grid.neighbor(hex_a, 0)).to(be_nil)
    end

    it "raises when direction is invalid" do
      grid = described_class.new([hex_a])

      expect { grid.neighbor(hex_a, 10) }.to(raise_error(Rhex::DirectionIndexOutOfRange))
    end
  end

  describe "#neighbors" do
    it "returns neighbors inside the grid" do
      hex_grid = grid(2)
      center = Rhex::AxialHex.new(0, 2)
      center.image_config = Rhex::ImageConfigs.image_config_for(:source)

      expected_neighbors = coords_to_hexes(
        [[1, 1], [0, 1], [-1, 2]],
        image_config: Rhex::ImageConfigs.image_config_for(:path)
      )

      hex_grid
        .merge(expected_neighbors)
        .merge([center])
        .to_pic("neighbors_inside_grid")

      expect(hex_grid.neighbors(center)).to(contain_exactly(*expected_neighbors))
    end
  end

  describe "#reachable" do
    it "shows reachable hexes" do
      source = Rhex::AxialHex.new(0, 0)
      source.image_config = Rhex::ImageConfigs.image_config_for(:source)

      obstacles = coords_to_hexes([
        [1, -1], [2, -1], [2, 0], [2, 1], [1, 2], [0, 2],
        [-1, 2], [-1, 1], [-2, 1], [-1, -1], [0, -2], [1, -3],
      ], image_config: Rhex::ImageConfigs.image_config_for(:obstacle))

      expected_reachable = coords_to_hexes([
        [0, 0], [1, 0], [0, 1], [1, 1], [-1, 0], [0, -1], [1, -2],
        [2, -3], [2, -2], [-2, -1], [-3, 0], [-2, 0], [-3, 1],
      ], image_config: Rhex::ImageConfigs.image_config_for(:path))

      hex_grid = square_grid(4)
        .merge(obstacles)
        .merge(expected_reachable + [])
        .merge([source])
      hex_grid.to_pic("reachable", orientation: Rhex::GridToPic::FLAT_TOPPED)

      expect(hex_grid.reachable(source, 3, obstacles: obstacles)).to(contain_exactly(*expected_reachable))
    end

    it "includes the source hex in the reachable list" do
      source = Rhex::AxialHex.new(0, 0)
      hex_grid = grid(0).merge([source])

      expect(hex_grid.reachable(source, 0)).to(contain_exactly(source))
    end

    it "excludes obstacles from reachable hexes" do
      source = Rhex::AxialHex.new(0, 0)
      obstacles = coords_to_hexes([[1, 0]])
      hex_grid = grid(1).merge([source]).merge(obstacles)

      reachable = hex_grid.reachable(source, 1, obstacles: obstacles)

      expect(reachable).not_to(include(Rhex::AxialHex.new(1, 0)))
    end

    it "raises when source is not in grid" do
      hex_grid = grid(0) # contains only (0,0)
      source = Rhex::AxialHex.new(1, 0)

      expect { hex_grid.reachable(source, 1) }.to(raise_error(Rhex::Grid::SourceHexNotInGrid))
    end
  end

  describe "#field_of_view" do
    it "calculates field of view" do
      hex_grid = grid(3)
      source = Rhex::AxialHex.new(-1, 2, image_config: Rhex::ImageConfigs.image_config_for(:source))
      obstacles = coords_to_hexes(
        [[-1, 1], [-1, 0], [0, -1], [1, -1], [1, 0]],
        image_config: Rhex::ImageConfigs.image_config_for(:obstacle)
      )

      expect_field_of_view = coords_to_hexes(
        [[0, 0], [0, 1], [1, 1], [0, 2], [-1, 3], [0, 3], [1, 2], [-3, 0], [-3, 1], [-3, 2], [-3, 3],
         [-2, 1], [-2, 2], [-2, 3], [2, 0], [2, 1], [3, 0], [3, -1],],
        image_config: Rhex::ImageConfigs.image_config_for(:path)
      )

      field_of_view = hex_grid.field_of_view(source, obstacles)

      hex_grid.merge(obstacles)
        .merge(expect_field_of_view)
        .merge([source])
        .to_pic("field_of_view")

      expect(field_of_view).to(contain_exactly(*expect_field_of_view))
    end

    it "raises when source is not in grid" do
      hex_grid = grid(0) # contains only (0,0)
      source = Rhex::AxialHex.new(1, 0)

      expect { hex_grid.field_of_view(source) }.to(raise_error(Rhex::Grid::SourceHexNotInGrid))
    end

    it "returns all other cells when obstacles are empty" do
      hex_grid = grid(1)
      source = hex_grid.fetch(Rhex::AxialHex.new(0, 0))

      field_of_view = hex_grid.field_of_view(source)

      expect(field_of_view).to(contain_exactly(*hex_grid.to_a - [source]))
      expect(field_of_view).not_to(include(source))
    end
  end

  describe "#bfs_path" do
    it "delegates to BfsPath" do
      grid = described_class.new([hex_a])
      target = instance_double(Rhex::AxialHex)
      obstacles = instance_double(Array)

      shortest_path = double
      bfs_path_instance = double

      expect(Rhex::BfsPath)
        .to(receive(:new).with(grid, obstacles: obstacles).and_return(bfs_path_instance))
      expect(bfs_path_instance).to(receive(:call).with(hex_a, target).and_return(shortest_path))

      expect(grid.bfs_path(hex_a, target, obstacles: obstacles)).to(eq(shortest_path))
    end
  end

  describe "#dfs_path" do
    it "delegates to DfsPath" do
      grid = described_class.new([hex_a])
      target = instance_double(Rhex::AxialHex)
      obstacles = instance_double(Array)

      path = double
      dfs_path_instance = double

      expect(Rhex::DfsPath)
        .to(receive(:new).with(grid, obstacles: obstacles).and_return(dfs_path_instance))
      expect(dfs_path_instance).to(receive(:call).with(hex_a, target).and_return(path))

      expect(grid.dfs_path(hex_a, target, obstacles: obstacles)).to(eq(path))
    end
  end

  describe "#fetch" do
    it "returns the stored hex" do
      grid = described_class.new([hex_a])

      expect(grid.fetch(hex_a)).to(eq(hex_a))
    end

    it "returns nil when hex is missing" do
      grid = described_class.new([hex_a])

      expect(grid.fetch(Rhex::AxialHex.new(2, 2))).to(be_nil)
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
