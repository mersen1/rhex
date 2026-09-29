# frozen_string_literal: true

require "spec_helper"
require "open3"

RSpec.describe(Rhex::Concerns::ImageConfig) do
  let(:config) do
    {
      hexagon: { color: "#fff", stroke_color: "#000" },
      text: { color: "#000", stroke_color: "none", font_size: 12 },
    }
  end
  let(:hex) { Rhex::AxialHex.new(0, 0, data: :payload, image_config: config) }

  it "leaves core hexes usable without the module" do
    output, status = Open3.capture2e(RbConfig.ruby, "-I", Rhex.root.join("lib").to_s, "-e", <<~RUBY)
      require "rhex"

      cube = Rhex::CubeHex.new(0, 0, 0, data: :payload)
      axial = Rhex::AxialHex.new(0, 0, data: :payload)
      derived = cube.neighbors + axial.ring(1) + [cube.to_axial, axial.to_cube]
      raise "Lost payload" unless derived.all? { |hex| hex.data == :payload }
      raise "Unexpected rendering settings" if ([cube, axial] + derived).any? { |hex| hex.respond_to?(:image_config) }
      raise "Unexpected image config state" if cube.instance_variable_defined?(:@image_config)

      decorated = Rhex::Decorators::FlatToppedHex.new(axial, size: 2)
      Rhex::Draw::Hexagon.new(gc: Magick::Draw.new, hex: decorated).call
    RUBY

    expect(status.success?).to(be(true), output)
  end

  it "accepts and validates settings for cube and axial hexes" do
    cube = Rhex::CubeHex.new(0, 0, 0, image_config: config)

    expect(cube.image_config).to(eq(config))
    expect(hex.image_config).to(eq(config))
    expect(hex.data).to(eq(:payload))
  end

  it "preserves settings through arithmetic and derived hexes" do
    vector = Rhex::CubeHex.new(1, 0, -1)
    derived = [hex + vector, hex - vector, hex * 2, hex.round, hex.lerp(vector, 0.5)] +
      hex.spiral_ring(2) + hex.neighbors + hex.linedraw(Rhex::AxialHex.new(3, 0))

    expect(derived.map(&:image_config).uniq).to(eq([config]))
    expect(derived.map(&:data).uniq).to(eq([:payload]))
  end

  it "preserves settings and data through coordinate conversions" do
    cube = hex.to_cube
    axial = cube.to_axial

    expect([cube.image_config, axial.image_config]).to(eq([config, config]))
    expect([cube.data, axial.data]).to(eq([:payload, :payload]))
  end

  it "allows settings to be assigned and cleared" do
    hex.image_config = config
    expect(hex.image_config).to(eq(config))

    hex.image_config = nil
    expect(hex.image_config).to(be_nil)
    expect(hex.neighbor(0).image_config).to(be_nil)
  end

  it "raises a prefixed error for invalid settings during initialization or assignment" do
    expect { Rhex::AxialHex.new(0, 0, image_config: { hexagon: {} }) }
      .to(raise_error(ArgumentError, /\AInvalid image_config: /))
    expect { hex.image_config = { text: {} } }
      .to(raise_error(ArgumentError, /\AInvalid image_config: /))
  end
end
