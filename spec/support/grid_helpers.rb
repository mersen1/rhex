# frozen_string_literal: true

module GridHelpers
  def grid(range)
    grid = Rhex::Grid.new

    (-range..range).to_a.each do |q|
      ([-range, -q - range].max..[range, -q + range].min).to_a.each do |r|
        grid.add(Rhex::AxialHex.new(q, r))
      end
    end

    grid
  end

  def square_grid(range)
    grid = Rhex::Grid.new

    (-range..range - 1).each do |col|
      (-range..range - 1).each do |row|
        axial_r = row - (col / 2)
        grid.add(Rhex::AxialHex.new(col, axial_r))
      end
    end

    grid
  end
end
