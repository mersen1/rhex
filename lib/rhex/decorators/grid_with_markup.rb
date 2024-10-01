# frozen_string_literal: true

module Rhex
  module Decorators
    class GridWithMarkup < SimpleDelegator
      def central_hex
        Rhex::AxialHex.new(
          median(q_map),
          median(r_map)
        )
      end

      def q_max
        @q_max ||= q_map.max
      end

      def q_min
        @q_min ||= q_map.min
      end

      def r_max
        @r_max ||= r_map.max
      end

      def r_min
        @r_min ||= r_map.min
      end

      private

      def q_map
        @q_map ||= to_a.map(&:q).sort
      end

      def r_map
        @r_map ||= to_a.map(&:r).sort
      end

      def median(array)
        length = array.length
        mid = length / 2

        if length.odd?
          array[mid]
        else
          (array[mid - 1] + array[mid]) / 2.0
        end
      end
    end
  end
end
