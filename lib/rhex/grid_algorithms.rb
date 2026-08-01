# frozen_string_literal: true

module Rhex
  # Hex grid algorithms: distances, obstacles, line-of-sight, path reconstruction.
  class GridAlgorithms
    INSTANCE = new.freeze

    def hex_distance(q1, r1, q2, r2)
      ((q1 - q2).abs + (q1 + r1 - q2 - r2).abs + (r1 - r2).abs) / 2
    end

    # Accepts anything that exposes q/r, not just Rhex hexes; a nil packed_key (non-integer
    # coordinates) would otherwise register every such obstacle under the same key and block nothing.
    def obstacle_packed_key_set(obstacles)
      Array(obstacles).each_with_object({}) do |h, acc|
        packed_key = h.packed_key if h.respond_to?(:packed_key)
        acc[packed_key || CoordinatePacker.pack(h.q, h.r)] = true
      end
    end

    def line_blocked?(source_q, source_r, target_q, target_r, obstacle_set)
      nudge_q, nudge_r, nudge_s = Constants::LINE_OF_SIGHT_NUDGE
      dist = hex_distance(source_q, source_r, target_q, target_r)
      return false if dist.zero?

      s1 = -source_q - source_r
      s2 = -target_q - target_r

      # Всё, что не зависит от шага, считаем один раз: цикл выполняется dist раз на каждый
      # гекс поля зрения, так что это самый горячий участок библиотеки.
      delta_q = target_q - source_q
      delta_r = target_r - source_r
      delta_s = s2 - s1

      1.upto(dist) do |i|
        # Ровно `i.to_f / dist`, а не `i * (1.0 / dist)`: вторая форма отличается на ulp
        # и может иначе округлить точку, лежащую на границе двух гексов.
        t = i.to_f / dist

        fq = source_q + (delta_q * t) + nudge_q
        fr = source_r + (delta_r * t) + nudge_r
        fs = s1 + (delta_s * t) + nudge_s

        rq = fq.round
        rr = fr.round
        rs = fs.round

        q_diff = (rq - fq).abs
        r_diff = (rr - fr).abs
        s_diff = (rs - fs).abs

        if q_diff > r_diff && q_diff > s_diff
          rq = -rr - rs
        elsif r_diff > s_diff
          rr = -rq - rs
        end

        return true if obstacle_set[CoordinatePacker.pack_unchecked(rq, rr)]
      end

      false
    end

    def reconstruct_path_from_parents(grid_hash, parents, start_packed_key, end_packed_key)
      path = []
      current_packed_key = end_packed_key

      loop do
        hex = grid_hash[current_packed_key]
        raise Grid::PathNotFoundError unless hex

        path << hex
        break if current_packed_key == start_packed_key

        current_packed_key = parents[current_packed_key]
        raise Grid::PathNotFoundError unless current_packed_key
      end

      path.reverse
    end
  end
end
