# frozen_string_literal: true

module Rhex
  module CanvasMarkups
    class AutoCanvasMarkup
      extend Forwardable

      Center = Struct.new(:x, :y, keyword_init: true)

      def initialize(grid)
        @grid = Rhex::Decorators::GridWithMarkup.new(grid)
      end

      def width
        (q_max - q_min + 1) * central_hex.width
      end
      alias_method :cols, :width

      def height
        (r_max - r_min + 1) * central_hex.height
      end
      alias_method :rows, :height

      def center
        @center ||= Center.new(
          x: (cols / 2) - central_hex.coordinates.x,
          y: (rows / 2) - central_hex.coordinates.y
        ).freeze
      end

      private

      attr_reader :grid

      def_delegators :grid, :hex_size
      def_delegators :grid, :q_max
      def_delegators :grid, :q_min
      def_delegators :grid, :r_max
      def_delegators :grid, :r_min

      def central_hex
        @central_hex ||= grid.decorate_hex(grid.central_hex)
      end
    end
  end
end
