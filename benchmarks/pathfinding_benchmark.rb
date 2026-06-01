# frozen_string_literal: true

# Benchmark for Rhex's heavy grid computations:
#   bfs_path, dfs_path, astar_path, reachable, field_of_view
#
# Measures both time (per-call, ms) and memory (allocations per call, plus the
# retained footprint of each grid).
#
# Run from the project root:
#   bundle exec ruby benchmarks/pathfinding_benchmark.rb
#
# Results are logged per gem version in the "Benchmarks" section of README.md.
#
# Grids are built as spiral rings of increasing radius. The number of hexes in a
# spiral ring of radius N is 3*N^2 + 3*N + 1, so the work grows quadratically.

require "benchmark"
require "objspace"
require_relative "../lib/rhex"

# Radii to benchmark and how many times to repeat each timed measurement.
RADII = [50, 100, 150, 200].freeze
REPETITIONS = 20

# field_of_view is O(N * radius) (a line-of-sight scan to every cell), so it is
# only timed/measured on grids up to this radius to keep runtime bounded.
FOV_MAX_RADIUS = 100

def build_grid(radius)
  Rhex::Grid.new(Rhex::AxialHex.new(0, 0).spiral_ring(radius))
end

# A deterministic ~20% scatter of obstacles. The r == 0 row (the straight
# corridor from the source at (0,0) to the target at (radius,0)) is always left
# open, so a path is guaranteed to exist regardless of radius.
def build_obstacles(radius)
  (-radius..radius).flat_map do |q|
    (-radius..radius).filter_map do |r|
      next if r.zero?                          # keep the source->target corridor open
      next if (-q - r).abs > radius            # keep inside the hexagon (|s| <= radius)
      next if q.abs <= 1 && r.abs <= 1         # leave the area around the source open
      next unless ((q * 31) + (r * 7)) % 5 == 0 # deterministic ~20% density

      Rhex::AxialHex.new(q, r)
    end
  end
end

# Precise retained footprint of a grid: the grid object, its internal lookup
# hash, and every stored hex. Deterministic (unlike a heap-diff / RSS sample).
def grid_footprint(grid)
  total = ObjectSpace.memsize_of(grid)
  total += ObjectSpace.memsize_of(grid.instance_variable_get(:@hash))
  grid.each { |hex| total += ObjectSpace.memsize_of(hex) }
  total
end

# Allocations made during the block: [objects, bytes]. GC is disabled so nothing
# is reclaimed mid-measurement, making the heap delta a stable allocation proxy.
def measure_alloc
  GC.start
  GC.disable
  objs_before  = GC.stat(:total_allocated_objects)
  bytes_before = ObjectSpace.memsize_of_all
  yield
  objs  = GC.stat(:total_allocated_objects) - objs_before
  bytes = ObjectSpace.memsize_of_all - bytes_before
  [objs, bytes]
ensure
  GC.enable
  GC.start
end

def fmt_bytes(bytes)
  units = ["B", "KiB", "MiB", "GiB"]
  value = bytes.to_f
  unit  = 0
  while value >= 1024 && unit < units.size - 1
    value /= 1024
    unit += 1
  end
  format("%.2f %s", value, units[unit])
end

puts "Rhex pathfinding / grid benchmark"
puts "Ruby #{RUBY_VERSION}  |  timed repetitions per case: #{REPETITIONS}"
puts "=" * 88

RADII.each do |radius|
  grid          = build_grid(radius)
  grid_retained = grid_footprint(grid)

  source     = grid[Rhex::AxialHex.new(0, 0)]
  target     = grid[Rhex::AxialHex.new(radius, 0)] # far corner, distance == radius
  obstacles  = build_obstacles(radius)
  hex_count  = grid.size
  run_fov    = radius <= FOV_MAX_RADIUS

  puts
  puts "radius=#{radius}  hexes=#{hex_count}  obstacles=#{obstacles.size}  path_distance=#{radius}"
  puts "grid retained footprint: #{fmt_bytes(grid_retained)}"
  puts "-" * 88

  # ---- Time ----
  Benchmark.bm(24) do |bm|
    bm.report("bfs_path") { REPETITIONS.times { grid.bfs_path(source, target) } }
    bm.report("dfs_path") { REPETITIONS.times { grid.dfs_path(source, target) } }
    bm.report("astar_path") { REPETITIONS.times { grid.astar_path(source, target) } }
    bm.report("bfs_path (obstacles)") { REPETITIONS.times { grid.bfs_path(source, target, obstacles: obstacles) } }
    bm.report("astar_path (obstacles)") { REPETITIONS.times { grid.astar_path(source, target, obstacles: obstacles) } }
    bm.report("reachable(radius)") { REPETITIONS.times { grid.reachable(source, radius) } }
    bm.report("field_of_view") { REPETITIONS.times { grid.field_of_view(source) } } if run_fov
  end
  puts "  field_of_view: skipped (radius > #{FOV_MAX_RADIUS})" unless run_fov

  # ---- Memory (allocations per single call) ----
  cases = {
    "bfs_path" => -> { grid.bfs_path(source, target) },
    "dfs_path" => -> { grid.dfs_path(source, target) },
    "astar_path" => -> { grid.astar_path(source, target) },
    "bfs_path (obstacles)" => -> { grid.bfs_path(source, target, obstacles: obstacles) },
    "astar_path (obstacles)" => -> { grid.astar_path(source, target, obstacles: obstacles) },
    "reachable(radius)" => -> { grid.reachable(source, radius) },
  }
  cases["field_of_view"] = -> { grid.field_of_view(source) } if run_fov

  puts
  puts format("  %-24s %14s %16s", "memory / call", "objects", "bytes")
  cases.each do |label, callable|
    objs, bytes = measure_alloc(&callable)
    puts format("  %-24s %14d %16s", label, objs, fmt_bytes(bytes))
  end
end

puts
puts "=" * 88
puts "done"
