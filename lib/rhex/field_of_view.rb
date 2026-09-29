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
      # The default tracer cannot block a ray without obstacles. Custom collaborators
      # may apply other visibility rules, so only skip tracing for the default instance.
      no_obstacles = ga.equal?(GridAlgorithms::INSTANCE) && obstacle_set.empty?
      source_q = source.q
      source_r = source.r

      visible = []
      grid_hash.each_value do |hex|
        next if hex.equal?(start_hex)

        visible << hex if no_obstacles || !ga.line_blocked?(source_q, source_r, hex.q, hex.r, obstacle_set)
      end
      visible
    end

    private

    attr_reader :grid_hash, :obstacles, :grid_algorithms
  end
end
