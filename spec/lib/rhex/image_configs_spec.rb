# frozen_string_literal: true

require "spec_helper"

RSpec.describe(Rhex::ImageConfigs) do
  let(:image_configs_path) { Rhex.root.join("spec", "fixtures", "image_configs") }

  describe ".load!" do
    it "defines readers for every config file" do
      described_class.load!(image_configs_path)

      expect(described_class).to(respond_to(:obstacle_image_config, :path_image_config, :source_image_config))
      expect(described_class.path_image_config.hexagon.color).to(eq("#B8D3E0"))
    end
  end
end
