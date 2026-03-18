# frozen_string_literal: true

module Rhex
  class DfsPath
    def initialize(grid, obstacles: [], grid_algorithms: GridAlgorithms::INSTANCE)
      @grid = grid
      @obstacles = obstacles
      @grid_algorithms = grid_algorithms
    end

    def call(source, target)
      grid_hash = grid.instance_variable_get(:@hash)
      ga = grid_algorithms

      start_q = source.q
      start_r = source.r
      target_q = target.q
      target_r = target.r

      start_packed_key = CoordinatePacker.pack(start_q, start_r)
      target_packed_key = CoordinatePacker.pack(target_q, target_r)

      start_hex = grid_hash[start_packed_key]
      raise Grid::GridDoesNotContainSourceError unless start_hex
      raise Grid::GridDoesNotContainTargetError unless grid_hash[target_packed_key]
      return [start_hex] if start_packed_key == target_packed_key

      obstacle_set = ga.obstacle_packed_key_set(obstacles)
      visited = { start_packed_key => true }
      parents = {}
      stack = [start_hex]

      until stack.empty?
        current = stack.pop

        cq = current.q
        cr = current.r
        current_packed_key = current.packed_key

        neighs = []
        Constants::AXIAL_NEIGHBOR_DELTAS.each do |dq, dr|
          nq = cq + dq
          nr = cr + dr
          neighbor_packed_key = CoordinatePacker.pack(nq, nr)

          next if obstacle_set.key?(neighbor_packed_key) || visited.key?(neighbor_packed_key)

          n_hex = grid_hash[neighbor_packed_key]
          next unless n_hex

          neighs << [neighbor_packed_key, n_hex]
        end

        neighs.each do |neighbor_packed_key, n_hex|
          next if visited.key?(neighbor_packed_key)

          visited[neighbor_packed_key] = true
          parents[neighbor_packed_key] = current_packed_key

          if neighbor_packed_key == target_packed_key
            return ga.reconstruct_path_from_parents(grid_hash, parents, start_packed_key, neighbor_packed_key)
          end

          stack << n_hex
        end
      end

      raise Grid::PathNotFoundError
    end

    private

    attr_reader :grid, :obstacles, :grid_algorithms
  end
end
