# frozen_string_literal: true

module Rhex
  class AxialHex < CubeHex
    def initialize(q, r, data: nil)
      super(q, r, -q - r, data: data)
    end

    def to_cube
      CubeHex.new(q, r, s, data: data)
    end
  end
end
