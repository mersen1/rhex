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

      # A hex coming from another oriented grid is already wrapped — and possibly by a decorator of
      # a different orientation or hex_size, so unwrap before re-decorating instead of nesting.
      def prepare_hex(hex)
        decorate_hex(hex.is_a?(Rhex::Decorators::BaseOrientedHex) ? hex.__getobj__ : hex)
      end

      def hex_decorator_class
        raise NoMethodError, "method #{__method__} is not implemented"
      end
    end
  end
end
