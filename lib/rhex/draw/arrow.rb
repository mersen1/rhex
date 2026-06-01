# frozen_string_literal: true

module Rhex
  module Draw
    # Draws a direction arrow centered on the `from` hex, pointing towards the
    # `to` hex. Used to visualize the order in which a path traverses hexes.
    class Arrow
      extend Forwardable

      DEFAULT_CONFIG = {
        color: "#1A1A1A",
        stroke_color: "#1A1A1A",
        # Roughly matches the rendered weight of the coordinate labels.
        stroke_width: 2,
        # Length of the arrow shaft as a fraction of the hex size.
        length_ratio: 0.5,
        # Length of each arrowhead barb as a fraction of the hex size.
        head_ratio: 0.22,
        # Half-angle of the arrowhead, in degrees.
        head_angle: 28,
      }.freeze

      def initialize(gc:, from:, to:, config: DEFAULT_CONFIG)
        @gc = gc
        @from = from
        @to = to
        @config = config
      end

      def call
        angle = Math.atan2(to.coordinates.y - from.coordinates.y, to.coordinates.x - from.coordinates.x)

        # Center the arrow on the edge between the two hexes (their midpoint).
        mid_x = (from.coordinates.x + to.coordinates.x) / 2.0
        mid_y = (from.coordinates.y + to.coordinates.y) / 2.0

        half = (from.size * config[:length_ratio]) / 2.0
        tail_x = mid_x - (Math.cos(angle) * half)
        tail_y = mid_y - (Math.sin(angle) * half)
        tip_x = mid_x + (Math.cos(angle) * half)
        tip_y = mid_y + (Math.sin(angle) * half)

        gc.stroke(config[:stroke_color])
        gc.stroke_width(config[:stroke_width])
        gc.fill(config[:color])

        gc.line(tail_x, tail_y, tip_x, tip_y)
        draw_head(angle, tip_x, tip_y)
      end

      private

      attr_reader :gc, :from, :to, :config

      def draw_head(angle, tip_x, tip_y)
        head_length = from.size * config[:head_ratio]
        head_angle = config[:head_angle] * Rhex::Constants::DEG_TO_RAD

        [angle - head_angle, angle + head_angle].each do |barb_angle|
          gc.line(
            tip_x, tip_y,
            tip_x - (head_length * Math.cos(barb_angle)),
            tip_y - (head_length * Math.sin(barb_angle))
          )
        end
      end
    end
  end
end
