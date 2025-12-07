# frozen_string_literal: true

require "zeitwerk"
require "ostruct"
require "yaml"
require "delegate"
require "forwardable"
require "json"
require "pathname"
require "rmagick"

Zeitwerk::Loader.for_gem.setup

module Rhex
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
