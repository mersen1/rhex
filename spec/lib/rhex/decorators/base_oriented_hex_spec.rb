# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::Decorators::BaseOrientedHex) do
  let(:hex) { Rhex::AxialHex.new(0, 0) }

  describe "#coordinates" do
    it "raises NotImplementedError when coordinate_x is not implemented" do
      expect { described_class.new(hex, size: 2).coordinates }
        .to(raise_error(NotImplementedError, /coordinate_x/))
    end

    it "raises NotImplementedError when coordinate_y is not implemented" do
      subclass = Class.new(described_class) do
        def coordinate_x = 0
      end

      expect { subclass.new(hex, size: 2).coordinates }
        .to(raise_error(NotImplementedError, /coordinate_y/))
    end
  end

  describe "#radius" do
    it "derives the circumradius from size" do
      subclass = Class.new(described_class) do
        def coordinate_x = 0
        def coordinate_y = 0
      end

      expect(subclass.new(hex, size: 3).radius).to(be_within(1e-9).of((2.0 / Math.sqrt(3)) * 3))
    end
  end
end
