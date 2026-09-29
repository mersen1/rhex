# frozen_string_literal: true

# Run after building the extension: bundle exec ruby benchmarks/field_of_view_native_benchmark.rb
require "benchmark"
require "objspace"
require_relative "../lib/rhex"

abort "Build the native extension first" unless defined?(Rhex::Native)

radius = Integer(ENV.fetch("RADIUS", "30"))
repetitions = Integer(ENV.fetch("REPETITIONS", "3"))
hexes = (-radius..radius).flat_map do |q|
  (-radius..radius).filter_map do |r|
    Rhex::AxialHex.new(q, r) if (q + r).abs <= radius
  end
end
obstacle_cases = {
  "sparse" => [Rhex::AxialHex.new(radius, 0)],
  "dense" => hexes.select { |hex| ((hex.q * 31) + (hex.r * 7)) % 7 == 0 && (hex.q != 0 || hex.r != 0) },
}
source = Rhex::AxialHex.new(0, 0)

ruby_algorithms = Class.new(Rhex::GridAlgorithms) do
  def line_blocked?(source_q, source_r, target_q, target_r, obstacle_set)
    line_blocked_ruby?(source_q, source_r, target_q, target_r, obstacle_set)
  end
end.new

cases = {
  "Ruby" => Rhex::Grid.new(hexes, grid_algorithms: ruby_algorithms),
  "C" => Rhex::Grid.new(hexes),
}

obstacle_cases.each do |scenario, obstacles|
  expected = cases.fetch("Ruby").field_of_view(source, obstacles: obstacles).map(&:packed_key)
  actual = cases.fetch("C").field_of_view(source, obstacles: obstacles).map(&:packed_key)
  abort "Native result differs from Ruby" unless actual == expected

  puts "#{scenario}: radius=#{radius}, cells=#{hexes.size}, obstacles=#{obstacles.size}, repetitions=#{repetitions}"
  cases.each do |label, grid|
    grid.field_of_view(source, obstacles: obstacles)
    GC.start
    elapsed = Benchmark.realtime do
      repetitions.times { grid.field_of_view(source, obstacles: obstacles) }
    end
    GC.start
    gc_was_disabled = GC.disable
    begin
      before_objects = GC.stat(:total_allocated_objects)
      before_bytes = ObjectSpace.memsize_of_all
      grid.field_of_view(source, obstacles: obstacles)
      allocated_objects = GC.stat(:total_allocated_objects) - before_objects
      allocated_bytes = ObjectSpace.memsize_of_all - before_bytes
    ensure
      GC.enable unless gc_was_disabled
    end
    puts format(
      "%-5s %9.2f ms/call %8d objects/call %8.1f KiB/call",
      label, elapsed * 1000 / repetitions, allocated_objects, allocated_bytes / 1024.0
    )
  end
end
