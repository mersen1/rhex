# frozen_string_literal: true

module Rhex
  class FieldOfView
    def initialize(grid_hash, obstacles: [], grid_algorithms: GridAlgorithms::INSTANCE)
      @grid_hash = grid_hash
      @obstacles = obstacles
      @grid_algorithms = grid_algorithms
    end

    def call(source)
      ga = grid_algorithms

      start_packed_key = CoordinatePacker.pack(source.q, source.r)
      start_hex = grid_hash[start_packed_key]
      raise Grid::GridDoesNotContainSourceError unless start_hex

      obstacle_set = ga.obstacle_packed_key_set(obstacles)
      # Без препятствий #line_blocked? не может вернуть true ни для одного гекса,
      # поэтому трассировать лучи (O(cells * distance)) незачем.
      no_obstacles = obstacle_set.empty?
      source_q = source.q
      source_r = source.r

      grid_hash.each_with_object([]) do |(_key, hex), visible|
        next if hex.equal?(start_hex)

        visible << hex if no_obstacles || !ga.line_blocked?(source_q, source_r, hex.q, hex.r, obstacle_set)
      end
    end

    private

    attr_reader :grid_hash, :obstacles, :grid_algorithms
  end
end
