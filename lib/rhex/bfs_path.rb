# frozen_string_literal: true

module Rhex
  class BfsPath
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
      queue = [start_hex]
      front = 0

      while front < queue.size
        current = queue[front]
        front += 1

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

          dist = ga.hex_distance(nq, nr, target_q, target_r)
          cross = cross_product([start_q, start_r], [target_q, target_r], [nq, nr])
          neighs << [dist, cross, nq, nr, neighbor_packed_key, n_hex]
        end

        neighs.sort! if neighs.size > 1

        neighs.each do |entry|
          neighbor_packed_key = entry[4]
          n_hex = entry[5]
          next if visited.key?(neighbor_packed_key)

          visited[neighbor_packed_key] = true
          parents[neighbor_packed_key] = current_packed_key

          if neighbor_packed_key == target_packed_key
            return ga.reconstruct_path_from_parents(grid_hash, parents, start_packed_key, neighbor_packed_key)
          end

          queue << n_hex
        end
      end

      raise Grid::PathNotFoundError
    end

    private

    attr_reader :grid, :obstacles, :grid_algorithms

    def cross_product(start_qr, target_qr, neighbor_qr)
      sq, sr = start_qr
      tq, tr = target_qr
      nq, nr = neighbor_qr
      ((tq - sq) * (sr - nr) - (sq - nq) * (tr - sr)).abs
    end
  end
end
