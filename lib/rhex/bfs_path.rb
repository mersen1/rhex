# frozen_string_literal: true

module Rhex
  class BfsPath
    GridDoesNotContainSourceError = Class.new(StandardError)
    GridDoesNotContainTargetError = Class.new(StandardError)
    PathNotFoundError = Class.new(StandardError)
    NativeCallError = Class.new(StandardError)

    def initialize(grid, obstacles: [])
      @grid = grid
      @obstacles = obstacles
    end

    def call(source, target)
      raise GridDoesNotContainSourceError unless grid.include?(source)
      raise GridDoesNotContainTargetError unless grid.include?(target)

      return [source] if source == target

      path = native_path(source, target)
      return path unless path.nil?

      raise PathNotFoundError
    end

    private

    attr_reader :grid, :obstacles

    def grid_hex_for(hex)
      grid.fetch(hex) || hex
    end

    def native_path(source, target)
      hexes = grid.to_a
      return nil if hexes.empty?

      grid_qs, grid_rs = coordinate_pointers(hexes)
      obstacles_qs, obstacles_rs = coordinate_pointers(obstacles)

      out_capacity = hexes.size
      out_qs = FFI::MemoryPointer.new(:int32, out_capacity)
      out_rs = FFI::MemoryPointer.new(:int32, out_capacity)

      count = Rhex::Native::Grid.bfs_path(
        grid_qs,
        grid_rs,
        hexes.size,
        source.q,
        source.r,
        target.q,
        target.r,
        obstacles_qs,
        obstacles_rs,
        obstacles.size,
        out_qs,
        out_rs,
        out_capacity
      )

      raise NativeCallError if count.negative?
      return nil if count.zero?

      coordinates_from_pointers(out_qs, out_rs, count).map { |(q, r)| grid_hex_for(Rhex::AxialHex.new(q, r)) }
    end

    def coordinate_pointers(hexes)
      return [FFI::Pointer::NULL, FFI::Pointer::NULL] if hexes.empty?

      [
        FFI::MemoryPointer.new(:int32, hexes.size).put_array_of_int32(0, hexes.map(&:q)),
        FFI::MemoryPointer.new(:int32, hexes.size).put_array_of_int32(0, hexes.map(&:r)),
      ]
    end

    def coordinates_from_pointers(qs_pointer, rs_pointer, count)
      return [] if count <= 0

      qs_pointer.get_array_of_int32(0, count).zip(rs_pointer.get_array_of_int32(0, count))
    end
  end
end
