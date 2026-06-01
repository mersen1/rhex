# frozen_string_literal: true

module Rhex
  class AxialHex < CubeHex
    def initialize(q, r, data: nil, image_config: nil)
      super(q, r, -q - r, data: data, image_config: image_config)
    end

    def to_cube
      CubeHex.new(q, r, s, data: data, image_config: image_config)
    end
  end
end
