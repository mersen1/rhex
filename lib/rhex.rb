# frozen_string_literal: true

require "dry/validation"
require "zeitwerk"
require "yaml"
require "delegate"
require "forwardable"
require "pathname"
require "rmagick"

Zeitwerk::Loader.for_gem.setup

module Rhex
  DirectionIndexOutOfRange = Class.new(StandardError)

  class << self
    def root
      Pathname.new(File.expand_path("..", __dir__))
    end

    def configure
      yield self
    end

    def font_path
      @font_path ||= Pathname.new(root.join("fonts", "Inconsolata-Regular.ttf")).to_s
    end

    def font_path=(value)
      @font_path = Pathname.new(value).to_s
    end
  end
end

# Defined here rather than in `lib/rhex/grid.rb` on purpose: Zeitwerk only loads that file once
# `Rhex::Grid` is referenced, which would leave `to_grid` undefined right after `require "rhex"`.
module Enumerable
  def to_grid(klass = Rhex::Grid, *args, **kwargs, &)
    klass.new(self, *args, **kwargs, &)
  end
end
