# frozen_string_literal: true

module Rhex
  module Decorators
    class BaseOrientedHex < SimpleDelegator
      Coordinates = Struct.new(:x, :y, keyword_init: true)
      private_constant :Coordinates

      def initialize(obj, size:)
        super(obj)
        @size = size
      end

      attr_reader :size

      def coordinates
        @coordinates ||= Coordinates.new(x: coordinate_x, y: coordinate_y)
      end

      def radius
        (2.0 / Math.sqrt(3)) * size
      end

      private

      def coordinate_x
        raise(NotImplementedError, "#{self.class}#coordinate_x is not implemented")
      end

      def coordinate_y
        raise(NotImplementedError, "#{self.class}#coordinate_y is not implemented")
      end
    end
  end
end
