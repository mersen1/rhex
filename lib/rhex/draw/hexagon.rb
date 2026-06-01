# frozen_string_literal: true

module Rhex
  module Draw
    class Hexagon
      extend Forwardable

      Coordinates = Struct.new(:x, :y, keyword_init: true)
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
      private_constant :Coordinates, :DEFAULT_IMAGE_CONFIG

      VALIDATED_DEFAULT_IMAGE_CONFIG = begin
        result = Rhex::Contracts::ImageConfigContract.new.call(DEFAULT_IMAGE_CONFIG)
        raise(ArgumentError, "Invalid DEFAULT_IMAGE_CONFIG: #{result.errors.to_h}") if result.failure?

        result.to_h.freeze
      end
      private_constant :VALIDATED_DEFAULT_IMAGE_CONFIG

      def initialize(gc:, hex:, default_image_config: VALIDATED_DEFAULT_IMAGE_CONFIG)
        @gc = gc
        @hex = hex
        @default_image_config =
          if default_image_config.equal?(VALIDATED_DEFAULT_IMAGE_CONFIG)
            default_image_config
          else
            validation = Rhex::Contracts::ImageConfigContract.new.call(default_image_config)
            validation.failure? && raise(ArgumentError, "Invalid image_config: #{validation.errors.to_h}")

            validation.to_h
          end
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
          "#{hex.q},#{hex.r}"
        )
      end

      def polygon_coordinates
        @polygon_coordinates ||= begin
          angles_in_radians = hex.class::ANGLES.map { |angle| angle * Rhex::Constants::DEG_TO_RAD }

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
