# frozen_string_literal: true

module Rhex
  class DfsPath
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

      return [source] if source == target

      visited = { [source.q, source.r] => true }
      stack = [[source, [source]]]

      until stack.empty?
        current, path = stack.pop
        return path if current == target

        ordered_neighbors(current, target).each do |neighbor|
          key = [neighbor.q, neighbor.r]
          next if visited.key?(key) || obstacle?(neighbor)

          visited[key] = true
          next_hex = grid_hex_for(neighbor)
          stack.push([next_hex, path + [next_hex]])
        end
      end

      raise PathNotFoundError
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

    def ordered_neighbors(current, target)
      grid.neighbors(current).sort_by do |neighbor|
        [
          neighbor.distance(target),
          -neighbor.r,
          neighbor.q,
        ]
      end
    end
  end
end
