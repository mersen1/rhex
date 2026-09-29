# frozen_string_literal: true

require "spec_helper"

RSpec.describe("Native traversals") do
  let(:hexes) do
    (-3..3).flat_map do |q|
      (-3..3).filter_map { |r| Rhex::AxialHex.new(q, r) if (q + r).abs <= 3 }
    end
  end
  let(:ruby_algorithms) { Class.new(Rhex::GridAlgorithms).new }
  let(:native_grid) { Rhex::Grid.new(hexes) }
  let(:ruby_grid) { Rhex::Grid.new(hexes, grid_algorithms: ruby_algorithms) }

  it "returns the same BFS paths and errors as Ruby" do
    obstacles = [Rhex::AxialHex.new(1, 0), Rhex::AxialHex.new(0, -1)]
    endpoints = [
      [Rhex::AxialHex.new(-3, 0), Rhex::AxialHex.new(3, 0)],
      [Rhex::AxialHex.new(0, 3), Rhex::AxialHex.new(0, -3)],
      [Rhex::AxialHex.new(2, -2), Rhex::AxialHex.new(-2, 2)],
    ]

    [[], obstacles].each do |blocked|
      endpoints.each do |source, target|
        expected = ruby_grid.bfs_path(source, target, obstacles: blocked)
        actual = native_grid.bfs_path(source, target, obstacles: blocked)
        expect(actual.map(&:packed_key)).to(eq(expected.map(&:packed_key)))
        actual.each { |hex| expect(native_grid.fetch(hex)).to(be(hex)) }
      end
    end

    disconnected = Rhex::Grid.new([Rhex::AxialHex.new(0, 0), Rhex::AxialHex.new(2, 0)])
    expect { disconnected.bfs_path(Rhex::AxialHex.new(0, 0), Rhex::AxialHex.new(2, 0)) }
      .to(raise_error(Rhex::Grid::PathNotFoundError))
  end

  it "returns reachable cells in the same order as Ruby" do
    source = Rhex::AxialHex.new(0, 0)
    obstacles = [Rhex::AxialHex.new(1, 0), Rhex::AxialHex.new(0, -1)]

    [[], obstacles].each do |blocked|
      [-1, 0, 1, 2, 3].each do |limit|
        expected = ruby_grid.reachable(source, limit, obstacles: blocked)
        actual = native_grid.reachable(source, limit, obstacles: blocked)
        expect(actual.map(&:packed_key)).to(eq(expected.map(&:packed_key)))
        actual.each { |hex| expect(native_grid.fetch(hex)).to(be(hex)) }
      end
    end
  end

  it "falls back to Ruby for large coordinates" do
    source = Rhex::AxialHex.new(1 << 29, 0)
    target = Rhex::AxialHex.new((1 << 29) + 1, 0)
    grid = Rhex::Grid.new([source, target])

    expect(grid.bfs_path(source, target)).to(eq([source, target]))
    expect(grid.reachable(source, 1)).to(eq([source, target]))
  end

  it "works when the extension is unavailable" do
    hide_const("Rhex::Native") if defined?(Rhex::Native)
    source = Rhex::AxialHex.new(0, 0)
    target = Rhex::AxialHex.new(1, 0)

    expect(native_grid.bfs_path(source, target)).to(eq([source, target]))
    expect(native_grid.reachable(source, 1)).to(include(source, target))
  end

  it "treats false entries and a false hash default as absent cells" do
    corridor = (0..3).map { |q| Rhex::AxialHex.new(q, 0) }
    [Hash.new(false), { Rhex::CoordinatePacker.pack(0, 1) => false }].each do |grid_hash|
      corridor.each { |hex| grid_hash[hex.packed_key] = hex }
      expect(Rhex::BfsPath.new(grid_hash).call(corridor.first, corridor.last)).to(eq(corridor))
      expect(Rhex::Reachable.new(grid_hash).call(corridor.first, 1)).to(eq(corridor.first(2)))
    end
  end

  it "matches Ruby on reproducible maps with holes, blocked endpoints and boundary coordinates" do
    random = Random.new(73519)
    bound = (1 << 29) - 1
    [[0, 0], [bound - 2, 0], [-bound + 2, 0], [0, bound - 2], [0, -bound + 2]].each do |q, r|
      15.times do
        cells = hexes.map { |hex| Rhex::AxialHex.new(hex.q + q, hex.r + r) }
          .select { random.rand > 0.25 }
        source, target = cells.sample(2, random: random)
        obstacles = cells.select { random.rand < 0.2 }
        native = Rhex::Grid.new(cells)
        ruby = Rhex::Grid.new(cells, grid_algorithms: ruby_algorithms)

        paths = [ruby, native].map do |grid|
          grid.bfs_path(source, target, obstacles: obstacles)
        rescue Rhex::Grid::PathNotFoundError => error
          error.class
        end
        expect(paths.last).to(eq(paths.first))

        [-1, 0, 1, 3, 8, 1.5, Float::INFINITY, 1 << 40].each do |limit|
          expect(native.reachable(source, limit, obstacles: obstacles))
            .to(eq(ruby.reachable(source, limit, obstacles: obstacles)))
        end
      end
    end
  end

  it "preserves decorated grid objects in both traversals" do
    native = Rhex::PointyToppedGrid.new(hexes, hex_size: 10)
    ruby = Rhex::Grid.new(native.to_a, grid_algorithms: ruby_algorithms)
    source = Rhex::AxialHex.new(-2, 0)
    target = Rhex::AxialHex.new(2, 0)

    [native.bfs_path(source, target), native.reachable(source, 3)].zip(
      [ruby.bfs_path(source, target), ruby.reachable(source, 3)]
    ).each do |actual, expected|
      expect(actual.map(&:packed_key)).to(eq(expected.map(&:packed_key)))
      actual.each { |hex| expect(hex).to(be(native.fetch(hex))) }
    end
  end

  context "with the native extension" do
    before do
      skip "Native extension is not built" unless defined?(Rhex::Native)
    end

    it "finds targets whose packed keys require heap Integers on 32-bit Ruby" do
      source = Rhex::AxialHex.new((1 << 29) - 4, -1)
      target = Rhex::AxialHex.new(source.q + 1, -1)
      grid_hash = [source, target].to_h { |hex| [hex.packed_key, hex] }
      parents = Rhex::Native.bfs_parents(
        grid_hash, {}, source, source.packed_key, source.q, source.r,
        target.q, target.r, target.packed_key
      )

      expect(parents).to(be_a(Hash))
      expect(parents[target.packed_key]).to(eq(source.packed_key))
    end

    it "accepts movement budgets larger than the coordinate range" do
      source = hexes.first
      grid_hash = hexes.to_h { |hex| [hex.packed_key, hex] }
      result = Rhex::Native.reachable(grid_hash, {}, source, source.packed_key, 1 << 29)

      expect(result).to(eq(ruby_grid.reachable(source, 1 << 29)))
    end

    it "treats false and nil obstacle values as present keys" do
      source = Rhex::AxialHex.new(0, 0)
      target = Rhex::AxialHex.new(1, 0)
      grid_hash = [source, target].to_h { |hex| [hex.packed_key, hex] }
      [false, nil].each do |value|
        obstacles = { target.packed_key => value }
        expect(Rhex::Native.bfs_parents(
          grid_hash, obstacles, source, source.packed_key, source.q, source.r,
          target.q, target.r, target.packed_key
        )).to(be(false))
        expect(Rhex::Native.reachable(grid_hash, obstacles, source, source.packed_key, 1)).to(eq([source]))
      end
    end

    it "declines hash subclasses and singleton overrides" do
      source = hexes.first
      target = hexes.last
      overridden = {}
      def overridden.key?(_key) = true

      [Class.new(Hash).new, overridden].each do |hash|
        [[hash, {}], [{}, hash]].each do |grid_hash, obstacles|
          expect(Rhex::Native.bfs_parents(
            grid_hash, obstacles, source, source.packed_key, source.q, source.r,
            target.q, target.r, target.packed_key
          )).to(be_nil)
          expect(Rhex::Native.reachable(grid_hash, obstacles, source, source.packed_key, 1)).to(be_nil)
        end
      end
    end

    it "keeps queued objects alive across GC and compaction callbacks" do
      source = Rhex::AxialHex.new(0, 0)
      target = Rhex::AxialHex.new(3, 0)
      calls = 0
      grid_hash = Hash.new do
        # Missing neighbors trigger collections while the C queue and neighbor buffer are live.
        calls += 1
        GC.verify_compaction_references(expand_heap: true, toward: :empty) if calls % 6 == 0
        nil
      end
      corridor = (0..3).map { |q| Rhex::AxialHex.new(q, 0) }
      corridor.each { |hex| grid_hash[hex.packed_key] = hex }

      expect(Rhex::BfsPath.new(grid_hash).call(source, target)).to(eq(corridor))
      expect(Rhex::Reachable.new(grid_hash).call(source, 10)).to(eq(corridor))
      expect(calls).to(be >= 6)
    end
  end
end
