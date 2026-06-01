# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::AstarPath) do
  def axial(q, r) = Rhex::AxialHex.new(q, r)

  let(:grid) { Rhex::Grid.new(Rhex::AxialHex.new(0, 0).spiral_ring(3)) }

  describe "#call" do
    context "when path exists" do
      it "returns the shortest path from source to target" do
        source = grid[axial(0, 0)]
        target = grid[axial(2, -1)]

        path = grid.astar_path(source, target)

        expect(path.first).to(eq(source))
        expect(path.last).to(eq(target))
        expect(path.length).to(eq(grid.bfs_path(source, target).length))
      end
    end

    context "when path is blocked by obstacles" do
      before { Rhex::ImageConfigs.load!(Rhex.root.join("spec", "fixtures", "image_configs")) }

      it "routes around obstacles and renders images/astar_path.png" do
        source = grid[axial(0, 0)]
        target = grid[axial(2, -1)]
        obstacle = Rhex::AxialHex.new(1, 0, image_config: Rhex::ImageConfigs.image_config_for(:obstacle))

        path = grid.astar_path(source, target, obstacles: [obstacle])

        expect(path).not_to(include(obstacle))
        expect(path.first).to(eq(source))
        expect(path.last).to(eq(target))

        path_hexes = path.map { |hex| grid.fetch(hex) }
        path_hexes.each { |hex| hex.image_config ||= Rhex::ImageConfigs.image_config_for(:path) }
        source.image_config = Rhex::ImageConfigs.image_config_for(:source)
        target.image_config = Rhex::ImageConfigs.image_config_for(:target)

        grid.merge([obstacle]).merge(path_hexes).merge([source, target])
          .to_pic("astar_path", orientation: :pointy_topped, path: path_hexes)
      end
    end

    context "when source equals target" do
      it "returns a single-element path" do
        source = grid[axial(0, 0)]

        path = grid.astar_path(source, source)

        expect(path).to(eq([source]))
      end
    end

    context "when path does not exist" do
      it "raises PathNotFoundError" do
        small_grid = Rhex::Grid[axial(0, 0), axial(3, 0)]
        source = small_grid[axial(0, 0)]
        target = small_grid[axial(3, 0)]

        expect { small_grid.astar_path(source, target) }.to(raise_error(Rhex::Grid::PathNotFoundError))
      end
    end

    context "when source is not in grid" do
      it "raises GridDoesNotContainSourceError" do
        source = axial(99, 99)
        target = grid[axial(0, 0)]

        expect { grid.astar_path(source, target) }.to(raise_error(Rhex::Grid::GridDoesNotContainSourceError))
      end
    end

    context "when target is not in grid" do
      it "raises GridDoesNotContainTargetError" do
        source = grid[axial(0, 0)]
        target = axial(99, 99)

        expect { grid.astar_path(source, target) }.to(raise_error(Rhex::Grid::GridDoesNotContainTargetError))
      end
    end
  end
end
