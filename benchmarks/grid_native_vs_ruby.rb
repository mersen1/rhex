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

# --- Optimized Ruby Implementations ---

def ruby_reachable_optimized(grid, source, movements_limit, obstacles)
  # Use Source as 'visited' set immediately to avoid 'fetch' check if possible,
  # or strict check like original
  start = grid.fetch(source) || raise(Rhex::Grid::GridDoesNotContainSourceError)

  # O(1) lookup for obstacles
  obstacle_lookup = obstacles.each_with_object({}) { |hex, acc| acc[[hex.q, hex.r]] = true }

  # Two-list approach (Current Wave & Next Wave) saves memory over array-of-arrays
  current_level = [start]
  visited_lookup = { [start.q, start.r] => true }
  results = [start]

  movements_limit.times do
    next_level = []

    current_level.each do |hex|
      grid.neighbors(hex).each do |neighbor|
        n_key = [neighbor.q, neighbor.r]

        # Skip visited or blocked
        next if visited_lookup.key?(n_key) || obstacle_lookup.key?(n_key)

        visited_lookup[n_key] = true
        results << neighbor
        next_level << neighbor
      end
    end

    current_level = next_level
    break if current_level.empty?
  end

  results
end

def ruby_field_of_view_optimized(grid, source, obstacles)
  start = grid.fetch(source) || raise(Rhex::Grid::GridDoesNotContainSourceError)

  # Fast return if no obstacles (all visible)
  # Using grid.to_a here is acceptable if we need to return an Array anyway,
  # but we exclude start.
  if obstacles.empty?
    return grid.to_a.tap { |ary| ary.delete(start) }
  end

  obstacle_lookup = obstacles.each_with_object({}) { |hex, acc| acc[[hex.q, hex.r]] = true }

  # Avoid grid.to_a - [start] allocation. Iterate and skip.
  visible = []

  # Assuming grid is Enumerable. If not, grid.to_a.each is fallback.
  grid.each do |hex|
    next if hex == start

    # Linedraw implies iteration. We stop at the first blocked point.
    # Note: line starts at 'start' (exclusive) or inclusive depending on impl.
    # Usually linedraw includes start and end.
    # We check if ANY point in the line is an obstacle.

    is_blocked = false
    # hex.linedraw(start) or start.linedraw(hex)
    line = start.linedraw(hex)

    # Check manual iteration to avoid 'any?' block overhead if line is long
    line.each do |point|
      # Skip checking the start hex itself if linedraw includes it
      next if point == start

      # Usually target hex is visible even if it is an obstacle itself?
      # Standard FOV usually hides things behind obstacles.
      # If point is obstacle:
      next unless obstacle_lookup.key?([point.q, point.r])

      # If the obstacle is the target hex itself, it might be visible (shadowcasting logic varies).
      # But this implementation mimics the original: "blocked = any? obstacle".
      # This implies if target is obstacle, it blocks itself?
      # Original code: blocked = any? { obstacle }. hex unless blocked.
      # So yes, if target is obstacle, it is not returned.
      is_blocked = true
      break
    end

    visible << hex unless is_blocked
  end

  visible
end

# --- Setup ---

# Increased range to make the benchmark meaningful (CPU bound rather than overhead bound)
range = Integer(ENV.fetch("RHEX_BENCH_RANGE", 20))
moves = Integer(ENV.fetch("RHEX_BENCH_MOVES", 3))
obstacle_ratio = ENV.fetch("RHEX_BENCH_OBSTACLE_RATIO", "0.1").to_f
seed = Integer(ENV.fetch("RHEX_BENCH_SEED", Random.new_seed))
rng = Random.new(seed)

puts "Building grid (Range: #{range})..."
grid = build_grid(range)
cells = grid.to_a
source = cells.sample(random: rng)
obstacles = cells.reject { |hex| hex == source }.sample((grid.size * obstacle_ratio).to_i, random: rng)

puts "Seed: #{seed}"
puts "Grid size: #{grid.size}, moves: #{moves}, obstacles: #{obstacles.size}"
puts "Source: #{source.q},#{source.r}"

# --- Warmup for C-Cache (if present) ---
begin
  grid.reachable(source, 1, obstacles: [])
rescue
  nil
end

# --- Benchmarks ---

puts "\n--- Reachable (BFS with Limit) ---"
Benchmark.ips do |x|
  x.report("native reachable") { grid.reachable(source, moves, obstacles: obstacles) }
  x.report("ruby reachable")   { ruby_reachable_optimized(grid, source, moves, obstacles) }
  x.compare!
end

puts "\n--- Field of View (Raycasting) ---"
Benchmark.ips do |x|
  x.report("native fov") { grid.field_of_view(source, obstacles) }
  x.report("ruby fov")   { ruby_field_of_view_optimized(grid, source, obstacles) }
  x.compare!
end
