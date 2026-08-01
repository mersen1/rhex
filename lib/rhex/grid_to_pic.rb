# frozen_string_literal: true

module Rhex
  class GridToPic
    extend Forwardable

    ORIENTATIONS = [
      FLAT_TOPPED = :flat_topped,
      POINTY_TOPPED = :pointy_topped,
    ].freeze

    ORIENTED_GRIDS_MAPPER = {
      FLAT_TOPPED => "Rhex::FlatToppedGrid",
      POINTY_TOPPED => "Rhex::PointyToppedGrid",
    }.freeze

    DEFAULT_ORIENTATION = FLAT_TOPPED
    DEFAULT_HEX_SIZE = 64

    def initialize(grid, hex_size: DEFAULT_HEX_SIZE, orientation: DEFAULT_ORIENTATION, path: nil)
      oriented_grid_class = Object.const_get(ORIENTED_GRIDS_MAPPER.fetch(orientation))
      oriented_grid = grid.to_grid(oriented_grid_class, hex_size: hex_size)

      @grid = oriented_grid
      @path = path
      @canvas_markup = Rhex::CanvasMarkups::AutoCanvasMarkup.new(oriented_grid)
    end

    def call(filename)
      gc.translate(center.x, center.y)

      grid.each { |hex| Draw::Hexagon.new(gc: gc, hex: hex).call }

      draw_path_arrows

      draw_and_save(filename)
    end

    private

    attr_reader :grid, :path, :canvas_markup

    def draw_path_arrows
      return if path.nil?

      # Dropping a missing hex silently would join its neighbours in #each_cons and draw one long
      # arrow across unrelated cells, so an incomplete path is an error rather than a bad picture.
      oriented_path = path.map do |hex|
        grid.fetch(hex) || raise(
          ArgumentError,
          "Path hex (#{hex.q}, #{hex.r}) is not present in the grid being rendered"
        )
      end

      oriented_path.each_cons(2) do |from, to|
        Draw::Arrow.new(gc: gc, from: from, to: to).call
      end
    end

    def_delegators :canvas_markup, :center
    def_delegators :canvas_markup, :cols
    def_delegators :canvas_markup, :rows

    def draw_and_save(filename)
      gc.draw(imgl)
      safe_filename = sanitize_filename(filename)
      imgl.write(Rhex.root.join("images", "#{safe_filename}.png").to_s)
    end

    def imgl
      @imgl ||=
        begin
          imgl = Magick::ImageList.new
          imgl.new_image(cols, rows, Magick::HatchFill.new("transparent", "lightcyan2"))
          imgl
        end
    end

    def gc
      @gc ||=
        begin
          gc = Magick::Draw.new
          gc.font = Rhex.font_path
          gc.text_align(Magick::CenterAlign)
          gc
        end
    end

    def sanitize_filename(filename)
      original = filename.to_s
      basename = File.basename(original, ".*")

      if basename.empty? || original != File.basename(original) || !basename.match?(/\A[\w-]+\z/)
        raise ArgumentError, "Invalid filename"
      end

      basename
    end
  end
end
