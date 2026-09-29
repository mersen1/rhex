# frozen_string_literal: true

module Rhex
  class AxialHex < CubeHex
    def initialize(q, r, **options)
      super(q, r, -q - r, **options)
    end

    def to_cube
      CubeHex.new(q, r, s, **hex_options)
    end
  end
end
