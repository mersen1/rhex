# frozen_string_literal: true

module Rhex
  class AstarPath
    class MinHeap
      def initialize = @heap = []
      def empty? = @heap.empty?

      def push(priority, payload)
        @heap << [priority, payload]
        sift_up(@heap.size - 1)
      end

      def pop
        swap(0, @heap.size - 1)
        min = @heap.pop
        sift_down(0) unless @heap.empty?
        min
      end

      private

      def sift_up(i)
        while i > 0
          parent = (i - 1) / 2
          break if @heap[parent][0] <= @heap[i][0]

          swap(parent, i)
          i = parent
        end
      end

      def sift_down(i)
        n = @heap.size
        loop do
          s = i
          l = (2 * i) + 1
          r = (2 * i) + 2
          s = l if l < n && @heap[l][0] < @heap[s][0]
          s = r if r < n && @heap[r][0] < @heap[s][0]
          break if s == i

          swap(s, i)
          i = s
        end
      end

      def swap(i, j)
        @heap[i], @heap[j] = @heap[j], @heap[i]
      end
    end

    private_constant :MinHeap

    def initialize(grid_hash, obstacles: [], grid_algorithms: GridAlgorithms::INSTANCE)
      @grid_hash = grid_hash
      @obstacles = obstacles
      @grid_algorithms = grid_algorithms
    end

    def call(source, target)
      ga = grid_algorithms

      target_q = target.q
      target_r = target.r

      start_packed_key = CoordinatePacker.pack(source.q, source.r)
      target_packed_key = CoordinatePacker.pack(target_q, target_r)

      start_hex = grid_hash[start_packed_key]
      raise Grid::GridDoesNotContainSourceError unless start_hex
      raise Grid::GridDoesNotContainTargetError unless grid_hash[target_packed_key]
      return [start_hex] if start_packed_key == target_packed_key

      obstacle_set = ga.obstacle_packed_key_set(obstacles)
      g_scores = { start_packed_key => 0 }
      parents = {}

      open_list = MinHeap.new
      open_list.push(ga.hex_distance(source.q, source.r, target_q, target_r), [0, start_packed_key, start_hex])

      until open_list.empty?
        _, (g, current_packed_key, current) = open_list.pop

        next if g_scores.fetch(current_packed_key, Float::INFINITY) < g

        if current_packed_key == target_packed_key
          return ga.reconstruct_path_from_parents(grid_hash, parents, start_packed_key, target_packed_key)
        end

        cq = current.q
        cr = current.r

        Constants::AXIAL_NEIGHBOR_DELTAS.each do |dq, dr|
          nq = cq + dq
          nr = cr + dr
          neighbor_packed_key = CoordinatePacker.pack(nq, nr)

          next if obstacle_set.key?(neighbor_packed_key)

          n_hex = grid_hash[neighbor_packed_key]
          next unless n_hex

          new_g = g + 1
          next if g_scores.key?(neighbor_packed_key) && g_scores[neighbor_packed_key] <= new_g

          g_scores[neighbor_packed_key] = new_g
          parents[neighbor_packed_key] = current_packed_key

          f = new_g + ga.hex_distance(nq, nr, target_q, target_r)
          open_list.push(f, [new_g, neighbor_packed_key, n_hex])
        end
      end

      raise Grid::PathNotFoundError
    end

    private

    attr_reader :grid_hash, :obstacles, :grid_algorithms
  end
end
