# frozen_string_literal: true

module Rhex
  class Grid
    include Enumerable

    GridDoesNotContainSourceError = Class.new(StandardError)
    GridDoesNotContainTargetError = Class.new(StandardError)
    PathNotFoundError = Class.new(StandardError)

    def self.[](*hexes)
      new(hexes)
    end

    def initialize(hexes = nil, grid_algorithms: GridAlgorithms::INSTANCE)
      @grid_algorithms = grid_algorithms
      @mutex = Mutex.new
      @hash = {}

      return if hexes.nil?

      hexes.each { add(_1) }
    end

    def add(hex)
      # Oriented grids store hexes wrapped in a screen-coordinate decorator; such a hex is still a
      # hex and must survive a round-trip back into a grid (`to_grid`, `merge`, `to_pic`).
      unless hex.is_a?(Rhex::CubeHex) || hex.is_a?(Rhex::Decorators::BaseOrientedHex)
        raise(
          ArgumentError,
          "Only Rhex::CubeHex or Rhex::AxialHex instances can be added to the grid, got: #{hex.class}"
        )
      end

      packed_key = key(hex)
      prepared = prepare_hex(hex)

      @mutex.synchronize { @hash[packed_key] = prepared }
      self
    end
    alias_method :<<, :add

    def each(&)
      return enum_for(:each) { size } unless block_given?

      # Iterating over a snapshot keeps the mutex free while the block runs, so a block that
      # mutates the grid neither deadlocks nor breaks the iteration.
      snapshot.each_value(&)
      self
    end

    def merge(other)
      if other.instance_of?(self.class)
        incoming = other.send(:snapshot)
        @mutex.synchronize { @hash.update(incoming) }
      else
        # Goes through #add so subclasses (see Concerns::OrientedGrid) still decorate their hexes.
        other.each { |hex| add(hex) }
      end

      self
    end

    # Single-key reads are left unsynchronized on purpose: one Hash lookup cannot observe a
    # half-applied write under the GVL, and taking the mutex here doubles the cost of the hottest
    # path in the library. Only bulk reads (#each, #to_a, #snapshot) need the lock.
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
      @mutex.synchronize { @hash.values }
    end

    def to_pic(
      filename,
      hex_size: Rhex::GridToPic::DEFAULT_HEX_SIZE,
      orientation: Rhex::GridToPic::DEFAULT_ORIENTATION,
      path: nil
    )
      Rhex::GridToPic.new(self, hex_size: hex_size, orientation: orientation, path: path).call(filename)
    end

    def to_grid(klass = Rhex::Grid, *args, **kwargs, &)
      return self if instance_of?(Rhex::Grid) && klass == Rhex::Grid

      klass.new(self, *args, **kwargs, &)
    end

    def neighbor(hex, direction_index)
      q, r, s = Rhex::Constants::DIRECTION_VECTORS[direction_index] || raise(Rhex::DirectionIndexOutOfRange)

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
      Reachable.new(snapshot, obstacles: obstacles, grid_algorithms: @grid_algorithms).call(source, movements_limit)
    end

    def field_of_view(source, obstacles: [])
      FieldOfView.new(snapshot, obstacles: obstacles, grid_algorithms: @grid_algorithms).call(source)
    end

    def bfs_path(source, target, obstacles: [])
      BfsPath.new(snapshot, obstacles: obstacles, grid_algorithms: @grid_algorithms).call(source, target)
    end

    def dfs_path(source, target, obstacles: [])
      DfsPath.new(snapshot, obstacles: obstacles, grid_algorithms: @grid_algorithms).call(source, target)
    end

    def astar_path(source, target, obstacles: [])
      AstarPath.new(snapshot, obstacles: obstacles, grid_algorithms: @grid_algorithms).call(source, target)
    end

    def fetch(hex)
      @hash[key(hex)]
    end
    alias_method :[], :fetch

    protected

    # Immutable view of the store: taken under the lock, handed to algorithms and iterators.
    def snapshot
      @mutex.synchronize { @hash.dup }
    end

    private

    # Overridden by Concerns::OrientedGrid to wrap hexes in a screen-coordinate decorator.
    def prepare_hex(hex)
      hex
    end

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

        return CoordinatePacker.pack_unchecked(hex[0], hex[1])
      end

      # Non-integer coordinates (an intermediate lerp result, a median, ...) have no packed key.
      # Returning the nil would silently collapse every such hex onto a single bucket.
      hex.packed_key || raise(
        ArgumentError,
        "Hex coordinates must be Integers to be used as a grid key, got: (#{hex.q.inspect}, #{hex.r.inspect})"
      )
    end
  end
end
