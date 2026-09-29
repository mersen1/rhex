# frozen_string_literal: true

module Rhex
  module Concerns
    module ImageConfig
      attr_reader :image_config

      def initialize(*coordinates, image_config: nil, **options)
        super(*coordinates, **options)
        self.image_config = image_config
      end

      def image_config=(value)
        return @image_config = nil unless value

        validation = Rhex::Contracts::ImageConfigContract.new.call(value)
        validation.failure? && raise(ArgumentError, "Invalid image_config: #{validation.errors.to_h}")

        @image_config = validation.to_h
      end

      private

      def hex_options
        super.merge(image_config: image_config)
      end
    end
  end
end
