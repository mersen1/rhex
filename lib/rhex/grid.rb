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
      @snapshot_hash = nil

      return if hexes.nil?

      hexes.each { add(_1) }
    end

    def add(hex)
      validate_hex!(hex)
      packed_key = key(hex)
      prepared = prepare_hex(hex)

      @mutex.synchronize do
        @hash[packed_key] = prepared
        @snapshot_hash = nil
      end
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
      incoming =
        if instance_of?(Rhex::Grid) && other.instance_of?(Rhex::Grid)
          other.send(:snapshot)
        else
          other.each_with_object({}) do |hex, entries|
            validate_hex!(hex)
            entries[key(hex)] = prepare_hex(hex)
          end
        end

      @mutex.synchronize do
        @hash.update(incoming)
        @snapshot_hash = nil
      end

      self
    end

    # All reads use the same mutex as writes. This keeps the contract valid on Ruby runtimes
    # without MRI's GVL and makes #merge visible as one update.
    def include?(hex)
      packed_key = key(hex)
      @mutex.synchronize { @hash.key?(packed_key) }
    end

    def exclude?(hex)
      !include?(hex)
    end

    def size
      @mutex.synchronize { @hash.size }
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

    # The key is computed directly, without an intermediate coordinate array and its validation:
    # #neighbors is the most common way to walk a grid.
    def neighbor(hex, direction_index)
      dq, dr = Rhex::Constants::AXIAL_NEIGHBOR_DELTAS[direction_index] ||
        raise(Rhex::DirectionIndexOutOfRange)

      packed_key = CoordinatePacker.pack(hex.q + dq, hex.r + dr)
      @mutex.synchronize { @hash[packed_key] }
    end

    def neighbors(hex)
      q = hex.q
      r = hex.r

      @mutex.synchronize do
        Rhex::Constants::AXIAL_NEIGHBOR_DELTAS.filter_map do |dq, dr|
          @hash[CoordinatePacker.pack(q + dq, r + dr)]
        end
      end
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
      packed_key = key(hex)
      @mutex.synchronize { @hash[packed_key] }
    end
    alias_method :[], :fetch

    protected

    # Immutable view of the store: taken under the lock, handed to algorithms and iterators.
    def snapshot
      @mutex.synchronize { @snapshot_hash ||= @hash.dup.freeze }
    end

    private

    # Overridden by Concerns::OrientedGrid to wrap hexes in a screen-coordinate decorator.
    def prepare_hex(hex)
      hex
    end

    def validate_hex!(hex)
      # Decorated hexes must survive a round-trip through #to_grid and #merge.
      return if hex.is_a?(Rhex::CubeHex) || hex.is_a?(Rhex::Decorators::BaseOrientedHex)

      raise(
        ArgumentError,
        "Only Rhex::CubeHex or Rhex::AxialHex instances can be added to the grid, got: #{hex.class}"
      )
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
