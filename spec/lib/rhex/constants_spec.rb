# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::Constants) do
  describe "::DIRECTION_VECTORS" do
    it "lists the six cube direction vectors in order" do
      expect(described_class::DIRECTION_VECTORS).to(eq([
        [1, 0, -1],
        [1, -1, 0],
        [0, -1, 1],
        [-1, 0, 1],
        described_class::INITIAL_RING_VECTOR,
        [0, 1, -1],
      ]))
    end

    it "reuses INITIAL_RING_VECTOR for the fifth entry" do
      expect(described_class::DIRECTION_VECTORS[4]).to(be(described_class::INITIAL_RING_VECTOR))
    end
  end
end
