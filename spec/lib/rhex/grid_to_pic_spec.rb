# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Rhex::GridToPic do
  include GridHelpers

  describe '#call' do
    xit 'draws image using "image_config" attribute' do
      image_config_class = Rhex::Draw::Hexagon::ImageConfig
      image_properties_class = Rhex::Draw::Hexagon::ImageProperties

      obstacle_image_config = image_config_class.new(
        hexagon: image_properties_class.new(color: '#C2A3A3', stroke_color: '#B3B3B3'),
        text: image_properties_class.new(color: '#C2A3A3', stroke_color: '#C2A3A3')
      )
      path_image_config = image_config_class.new(
        hexagon: image_properties_class.new(color: '#B3D5E6', stroke_color: '#B3B3B3'),
        text: image_properties_class.new(color: '#B3D5E6', stroke_color: '#B3D5E6')
      )

      grid = grid(5)
      obstacles = [
        [1, -1], [2, -1], [2, 0], [2, 1], [1, 2], [0, 2],
        [-1, 2], [-1, 1], [-2, 1], [-1, -1], [0, -2], [1, -3], [-3, 2], [-4, 3], [-5, 4]
      ].map { Rhex::AxialHex.new(*_1, image_config: obstacle_image_config) }

      source = Rhex::AxialHex.new(0, 0, image_config: path_image_config)
      shortest_path = source.dijkstra_shortest_path(Rhex::AxialHex.new(-5, 5), grid, obstacles: obstacles)
      shortest_path = shortest_path.map { Rhex::AxialHex.new(_1.q, _1.r, image_config: path_image_config) }

      obstacles.merge(shortest_path).each { grid.add(_1) }

      expect { described_class.new(grid).call('dijkstra_shortest_path') }.not_to raise_error
    end
  end
end
