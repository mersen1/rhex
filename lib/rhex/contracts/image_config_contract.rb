# frozen_string_literal: true

module Rhex
  module Contracts
    class ImageConfigContract < Dry::Validation::Contract
      params do
        required(:hexagon).hash do
          required(:color).filled(:string)
          required(:stroke_color).filled(:string)
          optional(:size).maybe(:integer)
        end

        required(:text).hash do
          required(:color).filled(:string)
          required(:stroke_color).filled(:string)
          required(:font_size).filled(:integer)
        end
      end
    end
  end
end
