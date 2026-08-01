# frozen_string_literal: true

module Rhex
  module Decorators
    class FlatToppedHex < BaseOrientedHex
      ANGLES = [0, 60, 120, 180, 240, 300].freeze

      def height
        (3.0 / 2.0) * radius
      end

      def width
        Math.sqrt(3) * radius
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
