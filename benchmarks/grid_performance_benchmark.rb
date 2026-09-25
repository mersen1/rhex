# frozen_string_literal: true

# Run from the project root:
#   bundle exec ruby benchmarks/grid_performance_benchmark.rb
#
# Set RHEX_LIB_DIR to benchmark another checkout with the same workload, for example:
#   RHEX_LIB_DIR=/path/to/baseline/lib bundle exec ruby benchmarks/grid_performance_benchmark.rb
# RHEX_BENCH_RADIUS (default 40) and RHEX_BENCH_SCALE (default 1) adjust workload size.
# This is a comparative benchmark, not a CI timing assertion: CPU scheduling and GC vary by host.

lib_dir = ENV.fetch("RHEX_LIB_DIR", File.expand_path("../lib", __dir__))
$LOAD_PATH.unshift(lib_dir)
require "rhex"

radius = Integer(ENV.fetch("RHEX_BENCH_RADIUS", "40"))
scale = Integer(ENV.fetch("RHEX_BENCH_SCALE", "1"))
raise ArgumentError, "radius and scale must be positive" unless radius.positive? && scale.positive?

grid = Rhex::Grid.new(Rhex::AxialHex.new(0, 0).spiral_ring(radius))
mutable_grid = Rhex::Grid.new(grid.to_a)
source = grid.fetch(Rhex::AxialHex.new(0, 0))
target = grid.fetch(Rhex::AxialHex.new(radius, 0))
merge_source = Rhex::Grid.new(source.spiral_ring(1))
path_finder = Rhex::AstarPath.new(grid.send(:snapshot))

def measure(name, operations, rounds: 5)
  # Warm the Ruby VM and populate any lazy caches before timing.
  yield
  samples = Array.new(rounds) do
    GC.start
    allocated_before = GC.stat(:total_allocated_objects)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    allocated = GC.stat(:total_allocated_objects) - allocated_before
    [elapsed, allocated]
  end

  median_time, median_allocations = samples.sort_by(&:first)[rounds / 2]
  puts format("%-20s %10d %12.2f %15.2f", name, operations, operations / median_time,
    median_allocations.to_f / operations)
end

puts "Rhex grid performance benchmark"
puts "Ruby #{RUBY_VERSION}; cells=#{grid.size}; radius=#{radius}; scale=#{scale}; lib=#{lib_dir}"
puts "loaded grid from #{Rhex::Grid.instance_method(:fetch).source_location.first}"
puts format("%-20s %10s %12s %15s", "operation", "calls/round", "calls/sec", "objects/call")

measure("fetch", 100_000 * scale) do
  (100_000 * scale).times { grid.fetch(target) }
end

measure("neighbors", 20_000 * scale) do
  (20_000 * scale).times { grid.neighbors(source) }
end

measure("snapshot_cached", 2_000 * scale) do
  (2_000 * scale).times { grid.send(:snapshot) }
end

measure("snapshot_after_add", 500 * scale) do
  (500 * scale).times do
    mutable_grid.add(source)
    mutable_grid.send(:snapshot)
  end
end

measure("astar_path", 1_000 * scale) do
  (1_000 * scale).times { grid.astar_path(source, target) }
end

measure("reused_astar", 1_000 * scale) do
  (1_000 * scale).times { path_finder.call(source, target) }
end

measure("merge", 1_000 * scale) do
  (1_000 * scale).times { Rhex::Grid.new.merge(merge_source) }
end

measure("parallel_fetch", 100_000 * scale) do
  4.times.map do
    Thread.new { (25_000 * scale).times { grid.fetch(target) } }
  end.each(&:value)
end
