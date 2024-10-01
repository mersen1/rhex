# frozen_string_literal: true

module Rhex
  module Decorators
    class PointyToppedHex < SimpleDelegator
      Coordinates = Struct.new(:x, :y, keyword_init: true)

      ANGLES = [30, 90, 150, 210, 270, 330].freeze

      def initialize(obj, size:)
        super(obj)
        @size = size
      end

      attr_reader :size

      def coordinates
        @coordinates ||= Coordinates.new(x: coordinate_x, y: coordinate_y)
      end

      def height
        Math.sqrt(3) * radius
      end

      def width
        (3.0 / 2.0) * radius
      end

      def radius
        (2.0 / Math.sqrt(3)) * size
      end

      private

      def coordinate_x
        width * (q + (r / 2.0))
      end

      def coordinate_y
        height * 3 / 4 * r
      end
    end
  end
end
