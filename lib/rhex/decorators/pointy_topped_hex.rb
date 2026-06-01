# frozen_string_literal: true

module Rhex
  module Decorators
    class PointyToppedHex < BaseOrientedHex
      ANGLES = [30, 90, 150, 210, 270, 330].freeze

      def height
        Math.sqrt(3) * radius
      end

      def width
        (3.0 / 2.0) * radius
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
