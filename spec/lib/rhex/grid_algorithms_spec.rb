# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::GridAlgorithms) do
  describe "#obstacle_packed_key_set" do
    it "indexes hexes by their packed key" do
      obstacle = Rhex::AxialHex.new(1, -1)

      expect(described_class::INSTANCE.obstacle_packed_key_set([obstacle]))
        .to(eq({ obstacle.packed_key => true }))
    end

    it "accepts any object exposing q/r" do
      duck = Struct.new(:q, :r).new(1, -1)

      expect(described_class::INSTANCE.obstacle_packed_key_set([duck]))
        .to(eq({ Rhex::CoordinatePacker.pack(1, -1) => true }))
    end

    it "raises instead of silently collapsing non-integer obstacles onto one key" do
      expect { described_class::INSTANCE.obstacle_packed_key_set([Rhex::CubeHex.new(0.5, 0.5, -1.0)]) }
        .to(raise_error(ArgumentError, /Hex coordinates must be Integers/))
    end
  end
end
