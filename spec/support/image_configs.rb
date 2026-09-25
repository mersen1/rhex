# frozen_string_literal: true

require "yaml"

module ImageConfigs
  module HexConfig
    attr_accessor :image_config
  end

  def with_image_config(hexes, name)
    config = name.is_a?(Hash) ? name : image_config_for(name)
    Array(hexes).each do |hex|
      hex.extend(HexConfig)
      hex.image_config = config
    end
    hexes
  end

  def image_config_for(name)
    key = name.to_s.sub(/_image_config\z/, "")
    file_path = image_configs_path.join("#{key}_image_config.yml")
    raise ArgumentError, "Unknown image config: #{name}" unless file_path.file?

    YAML.safe_load_file(file_path, symbolize_names: true)
  end

  private

  def image_configs_path
    Rhex.root.join("spec", "fixtures", "image_configs")
  end
end
