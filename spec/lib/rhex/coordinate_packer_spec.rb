# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::CoordinatePacker) do
  describe ".pack" do
    it "packs axial coordinates into a single integer key" do
      expect(described_class.pack(1, 2)).to(eq(described_class.pack(1, 2)))
      expect(described_class.pack(1, 2)).not_to(eq(described_class.pack(2, 1)))
    end

    it "keeps negative coordinates distinct" do
      keys = [[-1, -1], [-1, 1], [1, -1], [1, 1]].map { described_class.pack(*_1) }

      expect(keys.uniq.size).to(eq(4))
    end

    it "raises for non-integer coordinates" do
      expect { described_class.pack(0.5, 1) }
        .to(raise_error(ArgumentError, /Hex coordinates must be Integers/))
    end
  end
end
