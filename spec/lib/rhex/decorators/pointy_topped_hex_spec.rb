# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::Decorators::PointyToppedHex) do
  let(:hex) { Rhex::AxialHex.new(1, 2) }
  let(:size) { 4 }
  let(:decorated_hex) { described_class.new(hex, size: size) }

  it "exposes the configured size" do
    expect(decorated_hex.size).to(eq(size))
  end

  it "calculates geometry attributes" do
    expect(decorated_hex.radius).to(be_within(1e-6).of((2.0 / Math.sqrt(3)) * size))
    expect(decorated_hex.width).to(be_within(1e-6).of((3.0 / 2.0) * decorated_hex.radius))
    expect(decorated_hex.height).to(be_within(1e-6).of(Math.sqrt(3) * decorated_hex.radius))
  end

  it "returns coordinates based on q/r" do
    coordinates = decorated_hex.coordinates

    expect(coordinates.x).to(be_within(1e-6).of((24.0 / Math.sqrt(3))))
    expect(coordinates.y).to(eq(12.0))
    expect(decorated_hex.coordinates).to(be(coordinates)) # memoized
  end
end
