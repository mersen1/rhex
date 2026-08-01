# frozen_string_literal: true

module Rhex
  class FlatToppedGrid < Rhex::Grid
    include Rhex::Concerns::OrientedGrid

    def pointy_topped?
      false
    end

    private

    def hex_decorator_class
      Rhex::Decorators::FlatToppedHex
    end
  end
end
