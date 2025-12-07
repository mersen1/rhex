# frozen_string_literal: true

require 'rgl/adjacency'
require 'rgl/dijkstra'

module Rhex
  class DijkstraShortestPath
    GridDoesNotContainSourceError = Class.new(StandardError)
    GridDoesNotContainTargetError = Class.new(StandardError)

    def initialize(grid, obstacles: [])
      @grid = grid
      @obstacles = obstacles
      @grid_lookup = build_lookup(grid.to_a - obstacles)
      @obstacles_lookup = build_lookup(obstacles)
    end

    def call(source, target, _edge_weights_map = nil)
      raise GridDoesNotContainSourceError unless grid.include?(source)
      raise GridDoesNotContainTargetError unless grid.include?(target)

      bfs_shortest_path(source, target).map do |hex|
        Rhex::AxialHex.new(
          hex.q,
          hex.r,
          image_config: safe_path_image_config
        )
      end
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
          neighbor.q
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

    def safe_path_image_config
      return unless defined?(Rhex::ImageConfigs) && Rhex::ImageConfigs.respond_to?(:path_image_config)

      Rhex::ImageConfigs.path_image_config
    end
  end
end
