# frozen_string_literal: true

module Rhex
  class PointyToppedGrid < Rhex::Grid
    include Rhex::Concerns::OrientedGrid

    def pointy_topped?
      true
    end

    private

    def hex_decorator_class
      Rhex::Decorators::PointyToppedHex
    end
  end
end
