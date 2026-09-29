# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::GridAlgorithms) do
  describe "#line_blocked?" do
    let(:algorithms) { described_class::INSTANCE }

    it "matches the Ruby tracer across rays and obstacles" do
      obstacles = [[-2, 1], [0, -1], [1, 0], [2, -2]].to_h do |q, r|
        [Rhex::CoordinatePacker.pack(q, r), true]
      end

      (-2..2).each do |source_q|
        (-2..2).each do |source_r|
          (-3..3).each do |target_q|
            (-3..3).each do |target_r|
              args = [source_q, source_r, target_q, target_r, obstacles]
              expected = algorithms.send(:line_blocked_ruby?, *args)
              expect(algorithms.line_blocked?(*args)).to(eq(expected))
            end
          end
        end
      end
    end

    it "uses Ruby for coordinates outside the native range" do
      source_q = 1 << 29
      obstacles = { Rhex::CoordinatePacker.pack(source_q + 1, 0) => true }

      expect(algorithms.line_blocked?(source_q, 0, source_q + 1, 0, obstacles)).to(be(true))
    end

    it "preserves overridden hash lookups" do
      obstacles = Class.new(Hash) { def [](_key) = true }.new

      expect(algorithms.line_blocked?(0, 0, 1, 0, obstacles)).to(be(true))
    end

    it "works without the native extension" do
      hide_const("Rhex::Native") if defined?(Rhex::Native)
      obstacles = { Rhex::CoordinatePacker.pack(1, 0) => true }

      expect(algorithms.line_blocked?(0, 0, 1, 0, obstacles)).to(be(true))
    end

    it "preserves a custom distance implementation" do
      custom = Class.new(described_class) do
        def hex_distance(*) = 0
      end.new
      obstacles = { Rhex::CoordinatePacker.pack(1, 0) => true }

      expect(custom.line_blocked?(0, 0, 1, 0, obstacles)).to(be(false))
    end
  end

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
