# frozen_string_literal: true

module Rhex
  module Concerns
    module OrientedGrid
      def initialize(hexes = nil, hex_size:)
        @hex_size = hex_size

        super(hexes)
      end

      attr_reader :hex_size

      def decorate_hex(hex)
        hex_decorator_class.new(hex, size: hex_size)
      end

      def pointy_topped?
        raise NoMethodError, "method #{__method__} is not implemented"
      end

      private

      def prepare_hex(hex)
        decorate_hex(hex)
      end

      def hex_decorator_class
        raise NoMethodError, "method #{__method__} is not implemented"
      end
    end
  end
end
