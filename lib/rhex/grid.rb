# frozen_string_literal: true

module Rhex
  class Grid
    include Enumerable

    SourceHexNotInGrid = Class.new(StandardError)
    GridDoesNotContainSourceError = Class.new(StandardError)
    GridDoesNotContainTargetError = Class.new(StandardError)
    PathNotFoundError = Class.new(StandardError)

    # @!method reachable(source, movements_limit = 1, obstacles: [])
    #   Reachability via native C extension.
    #   @param source [Object] starting hex
    #   @param movements_limit [Integer] maximum steps
    #   @param obstacles [Array<Object>] blocked hexes
    #   @return [Array<Object>] reachable hexes including source

    # @!method field_of_view(source, obstacles = [])
    #   Visible cells via native C extension.
    #   @param source [Object] starting hex
    #   @param obstacles [Array<Object>] blocked hexes
    #   @return [Array<Object>] hexes visible from source (source excluded)

    def self.[](*hexes)
      new(hexes)
    end

    def initialize(hexes = nil)
      @hash = {}

      return if hexes.nil?

      hexes.each { add(_1) }
    end

    def add(hex)
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
      direction_vector = Rhex::Constants::DIRECTION_VECTORS[direction_index] || raise(Rhex::DirectionIndexOutOfRange)

      candidate = hex.add(Rhex::CubeHex.new(*direction_vector, data: hex.data, image_config: hex.image_config))
      fetch(candidate)
    end

    def neighbors(hex)
      Rhex::Constants::DIRECTION_VECTORS.length.times.each_with_object([]) do |direction_index, neighbors|
        hex_neighbor = neighbor(hex, direction_index)
        neighbors.push(hex_neighbor) if hex_neighbor
      end
    end

    def bfs_path(source, target, obstacles: [])
      Rhex::BfsPath.new(self, obstacles: obstacles).call(source, target)
    end

    def dfs_path(source, target, obstacles: [])
      Rhex::DfsPath.new(self, obstacles: obstacles).call(source, target)
    end

    def fetch(hex)
      @hash[key(hex)]
    end
    alias_method :[], :fetch

    private

    def key(hex)
      [hex.q, hex.r]
    end
  end
end

module Enumerable
  def to_grid(klass = Rhex::Grid, *args, **kwargs, &)
    klass.new(self, *args, **kwargs, &)
  end
end

require "rhex/rhex"
