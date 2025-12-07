# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::ImageConfigs) do
  let(:image_configs_path) { Rhex.root.join("spec", "fixtures", "image_configs") }

  describe ".load!" do
    it "loads configs accessible via image_config_for" do
      described_class.load!(image_configs_path)

      expect(described_class.image_config_for(:path).hexagon.color).to(eq("#B8D3E0"))
      expect(described_class.image_config_for("source").hexagon.stroke_color).to(eq("#B3B3B3"))
      expect { described_class.image_config_for(:missing) }.to(raise_error(ArgumentError))
    end
  end
end
