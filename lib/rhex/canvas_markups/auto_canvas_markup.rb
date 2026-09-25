# frozen_string_literal: true

module Rhex
  module CanvasMarkups
    class AutoCanvasMarkup
      extend Forwardable

      Center = Struct.new(:x, :y, keyword_init: true)
      STROKE_WIDTH = 1
      private_constant :Center, :STROKE_WIDTH

      def initialize(grid)
        @grid = Rhex::Decorators::GridWithMarkup.new(grid)
        @bounding_box = calculate_bounding_box.freeze
        @width = span_with_stroke(bounding_box[:x_max] - bounding_box[:x_min])
        @height = span_with_stroke(bounding_box[:y_max] - bounding_box[:y_min])
        bounding_center = calculate_bounding_center
        @center = Center.new(
          x: (cols / 2.0) - bounding_center.x,
          y: (rows / 2.0) - bounding_center.y
        ).freeze
        freeze
      end

      attr_reader :width, :height, :center
      alias_method :cols, :width
      alias_method :rows, :height

      private

      attr_reader :grid, :bounding_box

      def_delegators :grid, :hex_size

      def calculate_bounding_center
        Center.new(
          x: (x_min_with_stroke + x_max_with_stroke) / 2.0,
          y: (y_min_with_stroke + y_max_with_stroke) / 2.0
        )
      end

      def calculate_bounding_box
        x_min = Float::INFINITY
        x_max = -Float::INFINITY
        y_min = Float::INFINITY
        y_max = -Float::INFINITY

        grid.to_a.each do |hex|
          half_width = hex.width / 2.0
          half_height = hex.height / 2.0
          center = hex.coordinates

          xlo = center.x - half_width
          xhi = center.x + half_width
          ylo = center.y - half_height
          yhi = center.y + half_height

          x_min = xlo if xlo < x_min
          x_max = xhi if xhi > x_max
          y_min = ylo if ylo < y_min
          y_max = yhi if yhi > y_max
        end

        { x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max }
      end

      def span_with_stroke(span)
        (span + STROKE_WIDTH).ceil
      end

      def x_min_with_stroke
        bounding_box[:x_min] - STROKE_WIDTH / 2.0
      end

      def x_max_with_stroke
        bounding_box[:x_max] + STROKE_WIDTH / 2.0
      end

      def y_min_with_stroke
        bounding_box[:y_min] - STROKE_WIDTH / 2.0
      end

      def y_max_with_stroke
        bounding_box[:y_max] + STROKE_WIDTH / 2.0
      end
    end
  end
end
