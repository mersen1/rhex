# frozen_string_literal: true

require "spec_helper"

RSpec.describe("Thread safety") do
  it "publishes a grid merge only after all incoming cells are ready" do
    grid = Rhex::Grid.new
    ready = Queue.new
    release = Queue.new
    first = Rhex::AxialHex.new(0, 0)
    second = Rhex::AxialHex.new(1, 0)
    incoming = Enumerator.new do |yielded|
      yielded << first
      ready << true
      release.pop
      yielded << second
    end

    worker = Thread.new { grid.merge(incoming) }
    ready.pop
    expect(grid.size).to(eq(0))

    release << true
    worker.value
    expect(grid.to_a).to(contain_exactly(first, second))
  ensure
    release << true if worker&.alive?
    worker&.join
  end

  it "allows a path finder to be called concurrently without changing its input" do
    grid = Rhex::Grid.new(Rhex::AxialHex.new(0, 0).spiral_ring(4))
    source = grid[Rhex::AxialHex.new(0, 0)]
    target = grid[Rhex::AxialHex.new(4, 0)]
    obstacles = []
    path_finder = Rhex::AstarPath.new(grid.send(:snapshot), obstacles: obstacles)
    obstacles << Rhex::AxialHex.new(1, 0)

    paths = 8.times.map { Thread.new { path_finder.call(source, target) } }.map(&:value)

    expect(path_finder).to(be_frozen)
    expect(paths).to(all(eq(paths.first)))
    expect(paths.first.length).to(eq(5))
  end
end
