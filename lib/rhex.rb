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
      return @font_path if @font_path

      env_font = ENV["RHEX_FONT"]
      return nil unless env_font

      validate_font_path!(env_font, source: "ENV['RHEX_FONT']")
      env_font
    end

    def font_path_configured?
      !@font_path.nil? || ENV.key?("RHEX_FONT")
    end

    def font_path=(path)
      return @font_path = nil if path.nil?

      validate_font_path!(path, source: "Rhex.font_path")
      @font_path = path
    end

    private

    def validate_font_path!(path, source:)
      return if File.exist?(path)

      raise ArgumentError, "#{source} points to missing font file: #{path}"
    end
  end
end
