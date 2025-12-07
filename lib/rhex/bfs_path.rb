# frozen_string_literal: true

module Rhex
  class BfsPath
    GridDoesNotContainSourceError = Class.new(StandardError)
    GridDoesNotContainTargetError = Class.new(StandardError)
    PathNotFoundError = Class.new(StandardError)

    def initialize(grid, obstacles: [])
      @grid = grid
      @obstacles = obstacles
      @grid_lookup = build_lookup(grid.to_a - obstacles)
      @obstacles_lookup = build_lookup(obstacles)
    end

    def call(source, target)
      raise GridDoesNotContainSourceError unless grid.include?(source)
      raise GridDoesNotContainTargetError unless grid.include?(target)

      path = bfs_shortest_path(source, target)
      raise PathNotFoundError if path.empty?

      path
    end

    private

    attr_reader :grid, :obstacles, :grid_lookup, :obstacles_lookup

    def build_lookup(hexes)
      hexes.each_with_object({}) do |hex, acc|
        acc[[hex.q, hex.r]] = hex
      end
    end

    def grid_hex_for(hex)
      grid_lookup[[hex.q, hex.r]] || hex
    end

    def obstacle?(hex)
      obstacles_lookup.key?([hex.q, hex.r])
    end

    def bfs_shortest_path(source, target)
      return [source] if source == target

      queue = [source]
      visited = { [source.q, source.r] => true }
      previous = {}

      until queue.empty?
        current = queue.shift

        ordered_neighbors(current, target).each do |neighbor|
          key = [neighbor.q, neighbor.r]
          next if visited.key?(key) || obstacle?(neighbor)

          visited[key] = true
          previous[key] = current

          return build_path(previous, source, grid_hex_for(neighbor)) if neighbor == target

          queue << grid_hex_for(neighbor)
        end
      end

      []
    end

    def ordered_neighbors(current, target)
      current.neighbors(grid: grid).sort_by do |neighbor|
        [
          neighbor.distance(target),
          -neighbor.r,
          neighbor.q,
        ]
      end
    end

    def build_path(previous, source, target)
      path = [target]
      cursor = target

      while cursor != source
        cursor = previous[[cursor.q, cursor.r]]
        path << cursor
      end

      path.reverse
    end
  end
end
