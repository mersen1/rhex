# frozen_string_literal: true

module AxialHexHelpers
  def coords_to_hexes(coords, image_config: nil, **kwargs)
    hexes = coords.map { Rhex::AxialHex.new(*_1, **kwargs) }
    image_config ? with_image_config(hexes, image_config) : hexes
  end
end
