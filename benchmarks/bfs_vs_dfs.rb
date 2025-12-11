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

range = Integer(ENV.fetch("RHEX_BENCH_RANGE", 6))
obstacle_ratio = ENV.fetch("RHEX_BENCH_OBSTACLE_RATIO", "0.1").to_f

grid = build_grid(range)
source, target, obstacles = sample_paths(grid, obstacle_ratio)

puts "Grid size: #{grid.size}, obstacles: #{obstacles.size}"
puts "Source: #{source.q},#{source.r} -> Target: #{target.q},#{target.r}"

Benchmark.ips do |x|
  x.report("bfs_path") { grid.bfs_path(source, target, obstacles: obstacles) }
  x.report("dfs_path") { grid.dfs_path(source, target, obstacles: obstacles) }
  x.compare!
end
