# frozen_string_literal: true

module Rhex
  module Decorators
    class FlatToppedHex < SimpleDelegator
      Coordinates = Struct.new(:x, :y, keyword_init: true)

      ANGLES = [0, 60, 120, 180, 240, 300].freeze

      def initialize(obj, size:)
        super(obj)

        @size = size
      end

      attr_reader :size

      def coordinates
        @coordinates ||= Coordinates.new(x: coordinate_x, y: coordinate_y)
      end

      def height
        (3.0 / 2.0) * radius
      end

      def width
        Math.sqrt(3) * radius
      end

      def radius
        (2.0 / Math.sqrt(3)) * size
      end

      private

      def coordinate_x
        width * 3 / 4 * q
      end

      def coordinate_y
        height * (r + (q / 2.0))
      end
    end
  end
end
