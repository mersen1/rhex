# frozen_string_literal: true

module Rhex
  module Constants
    INITIAL_RING_VECTOR = [-1, 1, 0].freeze
    DIRECTION_VECTORS = [
      [1, 0, -1],
      [1, -1, 0],
      [0, -1, 1],
      [-1, 0, 1],
      INITIAL_RING_VECTOR,
      [0, 1, -1],
    ].freeze

    # Axial (q, r) steps matching DIRECTION_VECTORS order — for grid neighbor BFS/DFS.
    AXIAL_NEIGHBOR_DELTAS = DIRECTION_VECTORS.map { |q, r, _s| [q, r] }.freeze

    # Tiny offset for hex line-of-sight / linedraw (avoids ambiguous rounding on edges).
    LINE_OF_SIGHT_NUDGE = [1e-6, 2e-6, -3e-6].freeze
  end
end
