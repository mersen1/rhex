# frozen_string_literal: true

module Rhex
  module CanvasMarkups
    class AutoCanvasMarkup
      extend Forwardable

      Center = Struct.new(:x, :y, keyword_init: true)
      DEG_TO_RAD = Math::PI / 180.0
      STROKE_WIDTH = 1
      private_constant :Center, :DEG_TO_RAD, :STROKE_WIDTH

      def initialize(grid)
        @grid = Rhex::Decorators::GridWithMarkup.new(grid)
      end

      def width
        @width ||= span_with_stroke(x_max - x_min)
      end
      alias_method :cols, :width

      def height
        @height ||= span_with_stroke(y_max - y_min)
      end
      alias_method :rows, :height

      def center
        @center ||= Center.new(
          x: (cols / 2.0) - bounding_center.x,
          y: (rows / 2.0) - bounding_center.y
        ).freeze
      end

      private

      attr_reader :grid

      def_delegators :grid, :hex_size

      def bounding_center
        @bounding_center ||= Center.new(
          x: (x_min_with_stroke + x_max_with_stroke) / 2.0,
          y: (y_min_with_stroke + y_max_with_stroke) / 2.0
        )
      end

      def x_min
        @x_min ||= vertices.map(&:first).min
      end

      def x_max
        @x_max ||= vertices.map(&:first).max
      end

      def y_min
        @y_min ||= vertices.map(&:last).min
      end

      def y_max
        @y_max ||= vertices.map(&:last).max
      end

      def vertices
        @vertices ||= grid.to_a.flat_map { polygon_vertices(_1) }
      end

      def polygon_vertices(hex)
        hex.class::ANGLES.map do |deg|
          rad = deg * DEG_TO_RAD

          [
            hex.coordinates.x + (hex.size * Math.cos(rad)),
            hex.coordinates.y + (hex.size * Math.sin(rad)),
          ]
        end
      end

      def span_with_stroke(span)
        (span + STROKE_WIDTH).ceil
      end

      def x_min_with_stroke
        x_min - STROKE_WIDTH / 2.0
      end

      def x_max_with_stroke
        x_max + STROKE_WIDTH / 2.0
      end

      def y_min_with_stroke
        y_min - STROKE_WIDTH / 2.0
      end

      def y_max_with_stroke
        y_max + STROKE_WIDTH / 2.0
      end
    end
  end
end
