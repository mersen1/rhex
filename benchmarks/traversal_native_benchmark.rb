# frozen_string_literal: true

# Build ext/rhex first, then run: bundle exec ruby benchmarks/traversal_native_benchmark.rb
require "benchmark"
require "objspace"
require_relative "../lib/rhex"

abort "Build the native traversal extension first" unless defined?(Rhex::Native) &&
  Rhex::Native.respond_to?(:bfs_parents) && Rhex::Native.respond_to?(:reachable)

radii = ENV.fetch("RADII", "10,50,100").split(",").map { |value| Integer(value) }
repetitions = Integer(ENV.fetch("REPETITIONS", "5"))
abort "RADII and REPETITIONS must be positive" unless radii.all?(&:positive?) && repetitions.positive?

def measure_traversal(callable, repetitions)
  callable.call
  GC.start
  seconds = Benchmark.realtime { repetitions.times { callable.call } } / repetitions
  GC.start
  gc_was_disabled = GC.disable
  begin
    before_objects = GC.stat(:total_allocated_objects)
    before_bytes = ObjectSpace.memsize_of_all
    callable.call
    objects = GC.stat(:total_allocated_objects) - before_objects
    bytes = ObjectSpace.memsize_of_all - before_bytes
  ensure
    GC.enable unless gc_was_disabled
  end
  [seconds * 1000, objects, bytes / 1024.0]
end

radii.each do |radius|
  hexes = Rhex::AxialHex.new(0, 0).spiral_ring(radius)
  source = hexes.first
  target = Rhex::AxialHex.new(radius, 0)
  grids = {
    "Ruby" => Rhex::Grid.new(hexes, grid_algorithms: Rhex::GridAlgorithms.new),
    "C" => Rhex::Grid.new(hexes),
  }
  scattered = hexes.select { |hex| !hex.r.zero? && ((hex.q * 31) + (hex.r * 7)) % 5 == 0 }
  # A blocked target forces BFS to exhaust the connected component.
  { "open" => [], "scattered" => scattered, "blocked target" => [target] }.each do |scenario, obstacles|
    puts "radius=#{radius}, cells=#{hexes.size}, #{scenario}, repetitions=#{repetitions}"
    [:bfs_path, :reachable].each do |operation|
      calls = grids.transform_values do |grid|
        if operation == :bfs_path
          lambda do
            grid.bfs_path(source, target, obstacles: obstacles)
          rescue Rhex::Grid::PathNotFoundError
            :unreachable
          end
        else
          -> { grid.reachable(source, radius, obstacles: obstacles) }
        end
      end
      abort "Native #{operation} differs from Ruby" unless calls.fetch("Ruby").call == calls.fetch("C").call

      calls.each do |backend, callable|
        ms, objects, kib = measure_traversal(callable, repetitions)
        puts format("  %-10s %-4s %9.2f ms %9d objects %10.1f KiB", operation, backend, ms, objects, kib)
      end
    end
  end
end
