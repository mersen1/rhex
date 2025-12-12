# frozen_string_literal: true

module Rhex
  class BfsPath
    def initialize(grid, obstacles: [])
      @grid = grid
      @obstacles = obstacles
    end

    def call(source, target)
      grid.__send__(:bfs_path_native, source, target, obstacles: obstacles)
    end

    private

    attr_reader :grid, :obstacles
  end
end
