#!/usr/bin/env ruby
# frozen_string_literal: true

begin
  require "bundler/setup"
rescue LoadError
  # ok if bundler is not available
end

require "benchmark/ips"
require_relative "../lib/rhex"

# --- Helpers ---

def build_grid(range)
  grid = Rhex::Grid.new

  (-range..range).each do |q|
    ([-range, -q - range].max..[range, -q + range].min).each do |r|
      grid.add(Rhex::AxialHex.new(q, r))
    end
  end

  grid
end

def sample_paths(grid, obstacle_ratio, random:)
  cells = grid.to_a
  source = cells.sample(random: random)
  obstacles = cells.reject { |hex| hex == source }.sample((grid.size * obstacle_ratio).to_i, random: random)

  # Check if path is possible using native method to avoid endless loop in setup
  begin
    grid.bfs_path(source, cells.find { |c| c != source }, obstacles: obstacles)
  rescue Rhex::Grid::PathNotFoundError, Rhex::Grid::TargetIsObstacleError
    # Retry logic or simplified setup could go here,
    # but for benchmark assume we find a valid pair eventually or just pick randoms
  end

  # Simplified sampling: just pick random target that isn't an obstacle
  available = cells - obstacles - [source]
  target = available.sample(random: random) || source

  [source, target, obstacles]
end

# --- Optimized Ruby Algorithms ---

def ruby_bfs_optimized(grid, source, target, obstacles)
  # O(1) lookup for obstacles
  blocked = obstacles.each_with_object({}) { |h, acc| acc[[h.q, h.r]] = true }

  queue = [source]
  # Store parents: { [q, r] => parent_hex }
  # Also acts as 'visited' set
  came_from = { [source.q, source.r] => nil }

  until queue.empty?
    current = queue.shift # FIFO

    if current.q == target.q && current.r == target.r
      # Reconstruct path
      path = []
      while current
        path << current
        parent = came_from[[current.q, current.r]]
        current = parent
      end
      return path.reverse
    end

    grid.neighbors(current).each do |neighbor|
      n_key = [neighbor.q, neighbor.r]

      # Skip if visited or blocked
      next if came_from.key?(n_key) || blocked.key?(n_key)

      came_from[n_key] = current
      queue << neighbor
    end
  end
  []
end

def ruby_dfs_optimized(grid, source, target, obstacles)
  blocked = obstacles.each_with_object({}) { |h, acc| acc[[h.q, h.r]] = true }

  stack = [source]
  # Store parents for reconstruction
  came_from = { [source.q, source.r] => nil }

  until stack.empty?
    current = stack.pop # LIFO

    if current.q == target.q && current.r == target.r
      # Reconstruct path
      path = []
      while current
        path << current
        parent = came_from[[current.q, current.r]]
        current = parent
      end
      return path.reverse
    end

    grid.neighbors(current).each do |neighbor|
      n_key = [neighbor.q, neighbor.r]

      next if came_from.key?(n_key) || blocked.key?(n_key)

      came_from[n_key] = current
      stack << neighbor
    end
  end
  []
end

# --- Setup ---

range = Integer(ENV.fetch("RHEX_BENCH_RANGE", 30)) # Increased range for better stress test
obstacle_ratio = ENV.fetch("RHEX_BENCH_OBSTACLE_RATIO", "0.2").to_f
seed = Integer(ENV.fetch("RHEX_BENCH_SEED", Random.new_seed))
rng = Random.new(seed)

puts "Building grid (Range: #{range})..."
grid = build_grid(range)
source, target, obstacles = sample_paths(grid, obstacle_ratio, random: rng)

puts "Seed: #{seed}"
puts "Grid size: #{grid.size}, obstacles: #{obstacles.size}"
puts "Source: #{source.q},#{source.r} -> Target: #{target.q},#{target.r}"

# --- Warmup C-Cache ---
# Force C-extension to build its internal cache before benchmarking starts
puts "Warming up Native Cache..."
begin
  grid.bfs_path(source, source, obstacles: [])
rescue
  nil
end

# --- Benchmarks ---

puts "\n--- Breadth-First Search (Shortest Path) ---"
Benchmark.ips do |x|
  x.report("native bfs") { grid.bfs_path(source, target, obstacles: obstacles) }
  x.report("ruby bfs")   { ruby_bfs_optimized(grid, source, target, obstacles) }
  x.compare!
end

puts "\n--- Depth-First Search (Any Path) ---"
Benchmark.ips do |x|
  x.report("native dfs") { grid.dfs_path(source, target, obstacles: obstacles) }
  x.report("ruby dfs")   { ruby_dfs_optimized(grid, source, target, obstacles) }
  x.compare!
end
