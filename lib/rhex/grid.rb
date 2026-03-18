# frozen_string_literal: true

module Rhex
  class Grid
    GridDoesNotContainSourceError = Class.new(StandardError)
    GridDoesNotContainTargetError = Class.new(StandardError)
    PathNotFoundError = Class.new(StandardError)
    HexNotFoundError = Class.new(StandardError)

    def self.[](*hexes)
      new(hexes)
    end

    def initialize(hexes = nil, grid_algorithms: GridAlgorithms::INSTANCE)
      @grid_algorithms = grid_algorithms
      @hash = {}

      return if hexes.nil?

      hexes.each { add(_1) }
    end

    def add(hex)
      unless hex.is_a?(Rhex::CubeHex) || hex.is_a?(Rhex::AxialHex)
        raise(
          ArgumentError,
          "Only Rhex::CubeHex or Rhex::AxialHex instances can be added to the grid, got: #{hex.class}"
        )
      end

      @hash[key(hex)] = hex
      self
    end
    alias_method :<<, :add

    def each(&)
      return enum_for(:each) { size } unless block_given?

      @hash.each_value(&)
      self
    end

    def merge(other)
      if other.instance_of?(self.class)
        @hash.update(other.instance_variable_get(:@hash))
      else
        other.each { |hex| add(hex) }
      end

      self
    end

    def include?(hex)
      @hash.key?(key(hex))
    end

    def exclude?(hex)
      !include?(hex)
    end

    def size
      @hash.size
    end
    alias_method :length, :size

    def to_a
      @hash.values
    end

    def to_pic(
      filename,
      hex_size: Rhex::GridToPic::DEFAULT_HEX_SIZE,
      orientation: Rhex::GridToPic::DEFAULT_ORIENTATION
    )
      Rhex::GridToPic.new(self, hex_size: hex_size, orientation: orientation).call(filename)
    end

    def to_grid(klass = Rhex::Grid, *args, **kwargs, &)
      return self if instance_of?(Rhex::Grid) && klass == Rhex::Grid

      klass.new(self, *args, **kwargs, &)
    end

    def neighbor(hex, direction_index)
      q, r, s = Rhex::Constants::DIRECTION_VECTORS[direction_index] || raise(Rhex::DirectionIndexOutOfRange)

      hex = fetch(hex) || raise(HexNotFoundError)

      fetch([
        hex.q + q,
        hex.r + r,
        hex.s + s,
      ])
    end

    def neighbors(hex)
      Rhex::Constants::DIRECTION_VECTORS
        .map
        .with_index { |_, direction_index| neighbor(hex, direction_index) }.compact
    end

    def reachable(source, movements_limit = 1, obstacles: [])
      Reachable.new(self, obstacles: obstacles, grid_algorithms: @grid_algorithms).call(source, movements_limit)
    end

    def field_of_view(source, obstacles: [])
      FieldOfView.new(self, obstacles: obstacles, grid_algorithms: @grid_algorithms).call(source)
    end

    def bfs_path(source, target, obstacles: [])
      BfsPath.new(self, obstacles: obstacles, grid_algorithms: @grid_algorithms).call(source, target)
    end

    def dfs_path(source, target, obstacles: [])
      DfsPath.new(self, obstacles: obstacles, grid_algorithms: @grid_algorithms).call(source, target)
    end

    def fetch(hex)
      @hash[key(hex)]
    end
    alias_method :[], :fetch

    private

    def key(hex)
      if hex.is_a?(Array)
        # Validate that the array contains exactly 2 or 3 Integers
        unless (2..3).cover?(hex.size) && hex.all? { |coord| coord.is_a?(Integer) }
          raise(ArgumentError, "Hex must be an array of 2 or 3 Integers (e.g., [q, r]), got: #{hex.inspect}")
        end

        # Validate cubic coordinates property: q + r + s must equal 0
        if hex.size == 3 && hex.sum != 0
          raise(
            ArgumentError,
            "Invalid cube coordinates: sum of [q, r, s] must be 0, got: #{hex.inspect} (sum: #{hex.sum})"
          )
        end

        return CoordinatePacker.pack(hex[0], hex[1])
      end

      hex.packed_key
    end
  end
end

module Enumerable
  def to_grid(klass = Rhex::Grid, *args, **kwargs, &)
    klass.new(self, *args, **kwargs, &)
  end
end
