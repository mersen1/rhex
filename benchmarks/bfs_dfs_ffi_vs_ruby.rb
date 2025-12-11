#!/usr/bin/env ruby
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

def sample_paths(grid, obstacle_ratio)
  source = grid.to_a.sample
  obstacles = grid.to_a.reject { |hex| hex == source }.sample((grid.size * obstacle_ratio).to_i)

  reachable = grid.reachable(source, grid.size, obstacles: obstacles) - [source]
  if reachable.empty?
    obstacles = []
    reachable = grid.reachable(source, grid.size, obstacles: obstacles) - [source]
  end

  target = reachable.sample || source
  [source, target, obstacles]
end

def ruby_bfs_path(grid, source, target, obstacles)
  obstacle_lookup = obstacles.each_with_object({}) { |hex, acc| acc[[hex.q, hex.r]] = true }
  visited = { [source.q, source.r] => true }
  queue = [[source, [source]]]

  until queue.empty?
    hex, path = queue.shift
    return path if hex == target

    grid.neighbors(hex).each do |neighbor|
      key = [neighbor.q, neighbor.r]
      next if visited.key?(key) || obstacle_lookup.key?(key)

      visited[key] = true
      queue << [neighbor, path + [neighbor]]
    end
  end

  []
end

def ruby_dfs_path(grid, source, target, obstacles)
  obstacle_lookup = obstacles.each_with_object({}) { |hex, acc| acc[[hex.q, hex.r]] = true }
  visited = { [source.q, source.r] => true }
  stack = [[source, [source]]]

  until stack.empty?
    hex, path = stack.pop
    return path if hex == target

    grid.neighbors(hex).each do |neighbor|
      key = [neighbor.q, neighbor.r]
      next if visited.key?(key) || obstacle_lookup.key?(key)

      visited[key] = true
      stack << [neighbor, path + [neighbor]]
    end
  end

  []
end

range = Integer(ENV.fetch("RHEX_BENCH_RANGE", 8))
obstacle_ratio = ENV.fetch("RHEX_BENCH_OBSTACLE_RATIO", "0.1").to_f

grid = build_grid(range)
source, target, obstacles = sample_paths(grid, obstacle_ratio)

puts "Grid size: #{grid.size}, obstacles: #{obstacles.size}"
puts "Source: #{source.q},#{source.r} -> Target: #{target.q},#{target.r}"

Benchmark.ips do |x|
  x.report("ffi bfs_path") { grid.bfs_path(source, target, obstacles: obstacles) }
  x.report("ruby bfs_path") { ruby_bfs_path(grid, source, target, obstacles) }
  x.compare!
end

Benchmark.ips do |x|
  x.report("ffi dfs_path") { grid.dfs_path(source, target, obstacles: obstacles) }
  x.report("ruby dfs_path") { ruby_dfs_path(grid, source, target, obstacles) }
  x.compare!
end
