# frozen_string_literal: true

begin
  require "bundler/setup"
rescue LoadError
  # ok if bundler is not available
end

require "benchmark/ips"
require_relative "../lib/rhex"

def build_grid(range)
  grid = Rhex::Grid.new

  (-range..range).each do |q|
    ([-range, -q - range].max..[range, -q + range].min).each do |r|
      grid.add(Rhex::AxialHex.new(q, r))
    end
  end

  grid
end

def ruby_reachable(grid, source, movements_limit, obstacles)
  start = grid.fetch(source) || raise(Rhex::Grid::SourceHexNotInGrid)
  obstacle_lookup = obstacles.each_with_object({}) { |hex, acc| acc[[hex.q, hex.r]] = true }

  fringes = [[start]]
  visited = [start]
  visited_lookup = { [start.q, start.r] => true }

  1.upto(movements_limit) do |move|
    fringes << []
    fringes[move - 1].each do |hex|
      grid.neighbors(hex).each do |hex_neighbor|
        key = [hex_neighbor.q, hex_neighbor.r]
        next if visited_lookup.key?(key) || obstacle_lookup.key?(key)

        visited_lookup[key] = true
        visited << hex_neighbor
        fringes[move] << hex_neighbor
      end
    end
  end

  visited
end

def ruby_field_of_view(grid, source, obstacles)
  start = grid.fetch(source) || raise(Rhex::Grid::SourceHexNotInGrid)
  cells = grid.to_a - [start]
  return cells if obstacles.empty?

  obstacle_lookup = obstacles.each_with_object({}) { |hex, acc| acc[[hex.q, hex.r]] = true }

  cells.filter_map do |hex|
    blocked = start.linedraw(hex).any? { |point| obstacle_lookup.key?([point.q, point.r]) }
    hex unless blocked
  end
end

range = Integer(ENV.fetch("RHEX_BENCH_RANGE", 6))
moves = Integer(ENV.fetch("RHEX_BENCH_MOVES", 3))
obstacle_ratio = ENV.fetch("RHEX_BENCH_OBSTACLE_RATIO", "0.1").to_f
seed = Integer(ENV.fetch("RHEX_BENCH_SEED", Random.new_seed))
rng = Random.new(seed)

grid = build_grid(range)
cells = grid.to_a
source = cells.sample(random: rng)
obstacles = cells.reject { |hex| hex == source }.sample((grid.size * obstacle_ratio).to_i, random: rng)

puts "Seed: #{seed}"
puts "Grid size: #{grid.size}, moves: #{moves}, obstacles: #{obstacles.size}"
puts "Source: #{source.q},#{source.r}"

Benchmark.ips do |x|
  x.report("native reachable") { grid.reachable(source, moves, obstacles: obstacles) }
  x.report("ruby reachable") { ruby_reachable(grid, source, moves, obstacles) }
  x.compare!
end

Benchmark.ips do |x|
  x.report("native field_of_view") { grid.field_of_view(source, obstacles) }
  x.report("ruby field_of_view") { ruby_field_of_view(grid, source, obstacles) }
  x.compare!
end
