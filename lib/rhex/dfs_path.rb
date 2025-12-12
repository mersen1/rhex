# frozen_string_literal: true

module Rhex
  class DfsPath
    def initialize(grid, obstacles: [])
      @grid = grid
      @obstacles = obstacles
    end

    def call(source, target)
      grid.__send__(:dfs_path_native, source, target, obstacles: obstacles)
    end

    private

    attr_reader :grid, :obstacles
  end
end
