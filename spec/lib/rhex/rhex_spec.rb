# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex) do
  describe ".root" do
    it "returns the gem root path" do
      expect(described_class.root).to(be_a(Pathname))
      expect(File).to(exist(described_class.root.join("lib", "rhex.rb")))
    end
  end
end
