# frozen_string_literal: true

module Rhex
  module Draw
    class Hexagon
      extend Forwardable

      Coordinates = Struct.new(:x, :y, keyword_init: true)
      DEG_TO_RAD = Math::PI / 180.0
      DEFAULT_IMAGE_CONFIG = {
        hexagon: {
          color: "#F4F4F1",
          stroke_color: "#B3B3B3",
          size: 64,
        },
        text: {
          color: "#000000",
          stroke_color: "none",
          font_size: 32,
        },
      }.freeze
      private_constant :Coordinates, :DEG_TO_RAD, :DEFAULT_IMAGE_CONFIG

      def initialize(gc:, hex:, default_image_config: DEFAULT_IMAGE_CONFIG)
        @gc = gc
        @hex = hex

        validation = Rhex::Contracts::ImageConfigContract.new.call(default_image_config)
        validation.failure? && raise(ArgumentError, "Invalid image_config: #{validation.errors.to_h}")

        @default_image_config = default_image_config
      end

      def call
        draw_hexagon(image_config[:hexagon])
        draw_text(image_config[:text])
      end

      private

      attr_reader :gc, :hex, :default_image_config

      def_delegators :hex, :coordinates

      def image_config
        hex.image_config || default_image_config
      end

      def draw_hexagon(config)
        gc.fill(config[:color])

        gc.stroke(config[:stroke_color])
        gc.polygon(*polygon_coordinates)
      end

      def draw_text(config)
        gc.fill(config[:color])
        gc.stroke(config[:stroke_color])
        gc.font_size(config[:font_size])

        gc.text(
          coordinates.x, coordinates.y + (config[:font_size] / Math::PI),
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
        image_config[:hexagon][:size] || hex.size
      end
    end
  end
end
