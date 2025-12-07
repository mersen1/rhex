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
  end
end
