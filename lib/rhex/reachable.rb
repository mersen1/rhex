# frozen_string_literal: true

module Rhex
  class Reachable
    def initialize(grid_hash, obstacles: [], grid_algorithms: GridAlgorithms::INSTANCE)
      @grid_hash = grid_hash
      @obstacles = obstacles
      @grid_algorithms = grid_algorithms
    end

    def call(source, movements_limit = 1)
      ga = grid_algorithms

      start_packed_key = CoordinatePacker.pack(source.q, source.r)
      start_hex = grid_hash[start_packed_key]
      raise Grid::GridDoesNotContainSourceError unless start_hex

      movements_limit = 0 if movements_limit < 0

      obstacle_set = ga.obstacle_packed_key_set(obstacles)
      distance_map = { start_packed_key => 0 }
      result = [start_hex]
      queue = [start_hex]
      front = 0

      while front < queue.size
        current = queue[front]
        front += 1

        current_packed_key = current.packed_key
        current_dist = distance_map[current_packed_key]
        next if current_dist >= movements_limit

        next_dist = current_dist + 1

        Constants::AXIAL_NEIGHBOR_DELTAS.each do |dq, dr|
          neighbor_packed_key = CoordinatePacker.pack_unchecked(current.q + dq, current.r + dr)

          next if obstacle_set.key?(neighbor_packed_key) || distance_map.key?(neighbor_packed_key)

          n_hex = grid_hash[neighbor_packed_key]
          next unless n_hex

          distance_map[neighbor_packed_key] = next_dist
          result << n_hex
          queue << n_hex
        end
      end

      result
    end

    private

    attr_reader :grid_hash, :obstacles, :grid_algorithms
  end
end
