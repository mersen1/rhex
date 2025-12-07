# frozen_string_literal: true

module Rhex
  module Draw
    class Hexagon
      extend Forwardable

      ImageConfig = Struct.new(:hexagon, :text, keyword_init: true)
      ImageProperties = Struct.new(:color, :stroke_color, :font_size, :size, keyword_init: true)
      Coordinates = Struct.new(:x, :y, keyword_init: true)
      DEG_TO_RAD = Math::PI / 180.0

      DEFAULT_IMAGE_CONFIG = ImageConfig.new(
        hexagon: ImageProperties.new(
          color: "#F4F4F1",
          stroke_color: "#B3B3B3",
          size: nil
        ),
        text: ImageProperties.new(
          color: "#000000",
          stroke_color: "none",
          font_size: 32
        )
      ).freeze
      private_constant :DEFAULT_IMAGE_CONFIG

      def initialize(gc:, hex:, default_image_config: DEFAULT_IMAGE_CONFIG)
        @gc = gc
        @hex = hex
        @default_image_config = default_image_config
      end

      def call
        draw_hexagon(image_config.hexagon)
        draw_text(image_config.text)
      end

      private

      attr_reader :gc, :hex, :default_image_config

      def_delegators :hex, :coordinates

      def image_config
        config = hex.image_config
        return default_image_config if config.nil?

        ImageConfig.new(
          hexagon: merge_properties(default_image_config.hexagon, config.hexagon),
          text: merge_properties(default_image_config.text, config.text)
        )
      end

      def merge_properties(default_props, custom_props)
        return default_props if custom_props.nil?

        custom_hash = custom_props.to_h

        ImageProperties.new(
          color: custom_hash.fetch(:color, default_props.color),
          stroke_color: custom_hash.fetch(:stroke_color, default_props.stroke_color),
          font_size: custom_hash.fetch(:font_size, default_props.font_size),
          size: custom_hash.fetch(:size, default_props.size)
        )
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
              coordinates.x + (hexagon_size * Math.cos(angle_rad)),
              coordinates.y + (hexagon_size * Math.sin(angle_rad)),
            ]
          end
        end
      end

      def hexagon_size
        image_config.hexagon.size || hex.size
      end
    end
  end
end
