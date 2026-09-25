# frozen_string_literal: true

require "spec_helper"

RSpec.describe(ImageConfigs) do
  include ImageConfigs

  describe "#image_config_for" do
    it "loads a named fixture" do
      expect(image_config_for(:path)[:hexagon][:color]).to(eq("#B8D3E0"))
      expect(image_config_for("source")[:hexagon][:stroke_color]).to(eq("#B3B3B3"))
      expect(image_config_for(:path_image_config)[:hexagon][:color]).to(eq("#B8D3E0"))
      expect { image_config_for(:missing) }.to(raise_error(ArgumentError))
    end

    it "returns independent config values" do
      first = image_config_for(:path)
      first[:hexagon][:color].replace("changed")

      expect(image_config_for(:path)[:hexagon][:color]).not_to(eq("changed"))
    end

    it "adds image_config only to hexes selected by a spec" do
      selected = Rhex::AxialHex.new(0, 0)
      regular = Rhex::AxialHex.new(1, 0)

      with_image_config(selected, :path)

      expect(selected.image_config[:hexagon][:color]).to(eq("#B8D3E0"))
      expect(regular).not_to(respond_to(:image_config))
    end
  end
end
