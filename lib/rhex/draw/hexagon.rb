# frozen_string_literal: true

module Rhex
  module Draw
    class Hexagon
      extend Forwardable

      ImageConfig = Struct.new(:hexagon, :text, keyword_init: true)
      ImageProperties = Struct.new(:color, :stroke_color, :font_size, keyword_init: true)
      Coordinates = Struct.new(:x, :y, keyword_init: true)
      DEG_TO_RAD = Math::PI / 180.0

      DEFAULT_IMAGE_CONFIG = ImageConfig.new(
        hexagon: ImageProperties.new(
          color: "#FFFFE5",
          stroke_color: "#B3B3B3"
        ),
        text: ImageProperties.new(
          color: "#000000",
          stroke_color: "none",
          font_size: 32
        )
      ).freeze
      private_constant :DEFAULT_IMAGE_CONFIG

      def initialize(gc:, hex:)
        @gc = gc
        @hex = hex
      end

      def call
        draw_hexagon(image_config.hexagon)
        draw_text(image_config.text)
      end

      private

      attr_reader :gc, :hex

      def_delegators :hex, :coordinates

      def image_config
        hex.image_config || DEFAULT_IMAGE_CONFIG
      end

      def draw_hexagon(config)
        gc.fill(config.color)

        gc.stroke(config.stroke_color)
        gc.polygon(*polygon_coordinates)
      end

      def draw_text(config)
        gc.fill(config.color)
        gc.stroke(config.stroke_color)
        gc.font_size(config.font_size)

        gc.text(
          coordinates.x, coordinates.y + (config.font_size / Math::PI),
          "#{hex.q}, #{hex.r}"
        )
      end

      def polygon_coordinates
        @polygon_coordinates ||= begin
          angles_in_radians = hex.class::ANGLES.map { |angle| angle * DEG_TO_RAD }

          angles_in_radians.flat_map do |angle_rad|
            [
              coordinates.x + (hex.size * Math.cos(angle_rad)),
              coordinates.y + (hex.size * Math.sin(angle_rad)),
            ]
          end
        end
      end
    end
  end
end
