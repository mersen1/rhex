# frozen_string_literal: true

module Rhex
  class FieldOfView
    def initialize(grid, obstacles: [], grid_algorithms: GridAlgorithms::INSTANCE)
      @grid = grid
      @obstacles = obstacles
      @grid_algorithms = grid_algorithms
    end

    def call(source)
      grid_hash = grid.instance_variable_get(:@hash)
      ga = grid_algorithms

      start_packed_key = CoordinatePacker.pack(source.q, source.r)
      start_hex = grid_hash[start_packed_key]
      raise Grid::GridDoesNotContainSourceError unless start_hex

      obstacle_set = ga.obstacle_packed_key_set(obstacles)

      grid_hash.each_with_object([]) do |(_key, hex), visible|
        next if hex.equal?(start_hex)

        visible << hex unless ga.line_blocked?(source.q, source.r, hex.q, hex.r, obstacle_set)
      end
    end

    private

    attr_reader :grid, :obstacles, :grid_algorithms
  end
end
