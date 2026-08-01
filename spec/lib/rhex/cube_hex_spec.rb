# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::CubeHex) do
  include GridHelpers
  include AxialHexHelpers

  before do
    image_configs_path = Rhex.root.join("spec", "fixtures", "image_configs")

    Rhex::ImageConfigs.load!(image_configs_path)
  end

  describe "#spiral_ring" do
    it "returns a spiral list of hexagons" do
      center = Rhex::AxialHex.new(-1, -1)

      spiral_ring = center.spiral_ring(2)

      spiral_ring.to_grid.to_pic("spiral_ring", orientation: Rhex::GridToPic::POINTY_TOPPED)

      expect(spiral_ring.length).to(eq(19))
    end
  end

  describe "#ring" do
    it "returns a ring list of hexagons" do
      center = Rhex::AxialHex.new(0, 0)

      ring = center.ring(2)

      ring.to_grid.to_pic("ring")

      expect(ring.length).to(eq(12))
    end
  end

  describe "#linedraw" do
    it "returns straight path to the target" do
      source = Rhex::CubeHex.new(-4, 0, 4)
      target = Rhex::CubeHex.new(-1, -1, 2)

      expect(source.linedraw(target))
        .to(contain_exactly(
          source,
          Rhex::CubeHex.new(-3, 0, 3),
          Rhex::CubeHex.new(-2, -1, 3),
          target
        ))
    end
  end

  describe "#linedraw" do
    it "returns straight path to the target" do
      source = Rhex::AxialHex.new(-4, 0)
      target = Rhex::AxialHex.new(4, -2)

      path = source.linedraw(target)
      path.each { _1.image_config = Rhex::ImageConfigs.image_config_for(:path) }
      path.to_grid.to_pic("linedraw")

      expect(path)
        .to(contain_exactly(
          source,
          Rhex::AxialHex.new(-3, 0), Rhex::AxialHex.new(-2, 0), Rhex::AxialHex.new(-1, -1), Rhex::AxialHex.new(0, -1),
          Rhex::AxialHex.new(1, -1), Rhex::AxialHex.new(2, -1), Rhex::AxialHex.new(3, -2),
          target
        ))
    end
  end

  describe "#linedraw" do
    it "returns just the source when target is the source itself" do
      hex = Rhex::AxialHex.new(2, -1)

      expect(hex.linedraw(hex)).to(eq([hex]))
    end
  end

  describe "#distance" do
    it "calculates the distance between two hexes" do
      from = Rhex::AxialHex.new(0, 2)
      to = Rhex::AxialHex.new(0, -2)
      expect(from.distance(to)).to(eq(4))
    end
  end

  describe "#to_axial" do
    it "converts cube to axial" do
      cube = described_class.new(0, -1, 1)

      expect(cube.to_axial).to(eq(Rhex::AxialHex.new(0, -1)))
    end
  end

  describe "#==" do
    it "compares coordinates" do
      cube = described_class.new(1, -1, 0)

      expect(cube).to(eq(described_class.new(1, -1, 0)))
      expect(cube).not_to(eq(described_class.new(0, 0, 0)))
      expect(cube.eql?(cube)).to(be(true))
      expect(cube != described_class.new(0, -1, 1)).to(be(true))
      expect(cube.hash).to(eq([1, -1, 0].hash))
    end
  end

  describe "#reflection" do
    let(:hex) { described_class.new(1, 2, -3) }

    it "reflects across the q axis" do
      expect(hex.reflection_q).to(eq(described_class.new(1, -3, 2)))
    end

    it "reflects across the r axis" do
      expect(hex.reflection_r).to(eq(described_class.new(-3, 2, 1)))
    end

    it "reflects across the s axis" do
      expect(hex.reflection_s).to(eq(described_class.new(2, 1, -3)))
    end
  end

  describe "#neighbor" do
    it "returns neighbor in the given direction" do
      hex = described_class.new(0, 0, 0)

      expect(hex.neighbor(0)).to(eq(described_class.new(1, 0, -1)))
    end

    it "raises for invalid direction" do
      hex = described_class.new(0, 0, 0)

      expect { hex.neighbor(10) }.to(raise_error(Rhex::DirectionIndexOutOfRange))
    end
  end

  describe "#neighbors" do
    it "returns all 6 neighbors" do
      hex = described_class.new(0, 0, 0)

      expect(hex.neighbors.length).to(eq(6))
      expect(hex.neighbors).to(include(described_class.new(1, 0, -1)))
    end
  end

  describe "#spiral_ring" do
    it "raises when radius is zero" do
      hex = described_class.new(0, 0, 0)

      expect { hex.spiral_ring(0) }.to(raise_error(Rhex::CubeHex::RadiusCannotBeZero))
    end
  end

  describe "#round" do
    it "rounds with q component dominating" do
      hex = described_class.new(0.6, 0.2, -0.8)

      expect(hex.send(:round)).to(eq(described_class.new(1, 0, -1)))
    end

    it "rounds with r component dominating" do
      hex = described_class.new(0.2, 0.7, -0.9)

      expect(hex.send(:round)).to(eq(described_class.new(0, 1, -1)))
    end

    it "rounds with s component dominating" do
      hex = described_class.new(0.1, 0.2, -0.3)

      expect(hex.send(:round)).to(eq(described_class.new(0, 0, 0)))
    end
  end

  describe "#lerp" do
    it "interpolates towards the target" do
      source = described_class.new(0, 0, 0)
      target = described_class.new(4, -4, 0)

      expect(source.lerp(target, 0.5)).to(eq(described_class.new(2.0, -2.0, 0.0)))
      expect(source.lerp(target, 0.0)).to(eq(source))
    end
  end

  describe "payload propagation" do
    let(:image_config) { Rhex::ImageConfigs.image_config_for(:path) }
    let(:hex) { Rhex::AxialHex.new(0, 0, data: :payload, image_config: image_config) }

    it "keeps data and image_config in arithmetic results" do
      derived = hex + Rhex::CubeHex.new(1, 0, -1)

      expect(derived.data).to(eq(:payload))
      expect(derived.image_config).to(eq(hex.image_config))
      expect((hex - Rhex::CubeHex.new(1, 0, -1)).data).to(eq(:payload))
      expect((hex * 2).data).to(eq(:payload))
    end

    it "keeps data and image_config in derived hexes" do
      derived = hex.spiral_ring(2) + hex.neighbors + hex.linedraw(Rhex::AxialHex.new(3, 0))

      expect(derived.map(&:data).uniq).to(eq([:payload]))
      expect(derived.map(&:image_config).uniq).to(eq([hex.image_config]))
    end
  end

  describe "#image_config=" do
    it "raises a prefixed error for an invalid config" do
      expect { Rhex::AxialHex.new(0, 0, image_config: { hexagon: {} }) }
        .to(raise_error(ArgumentError, /\AInvalid image_config: /))
    end
  end
end
