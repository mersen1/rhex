# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::Concerns::OrientedGrid) do
  let(:dummy_class) do
    Class.new(Rhex::Grid) do
      include Rhex::Concerns::OrientedGrid
    end
  end

  it "raises when orientation helpers are not implemented" do
    grid = dummy_class.new(hex_size: 1)

    expect { grid.pointy_topped? }.to(raise_error(NoMethodError))
    expect { grid.send(:hex_decorator_class) }.to(raise_error(NoMethodError))
  end
end
