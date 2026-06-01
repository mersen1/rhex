# frozen_string_literal: true

module Rhex
  class ImageConfigs
    CONFIG_PATTERN = "*_config.yml"
    private_constant :CONFIG_PATTERN

    class << self
      def load!(image_configs_path)
        configs.clear

        path = File.join(image_configs_path, CONFIG_PATTERN)
        Dir.glob(path).each do |file_path|
          load_file!(file_path)
        end
      end

      def image_config_for(name)
        key = normalize_key(name)
        config = configs[key]
        return config if config

        raise ArgumentError, "Unknown image config: #{name}"
      end

      private

      def configs
        @configs ||= {}
      end

      def load_file!(file_path)
        extname = File.extname(file_path)
        filename = File.basename(file_path, extname)
        config = YAML.safe_load(File.read(file_path), symbolize_names: true)

        configs[normalize_key(filename)] = config
      end

      def normalize_key(name)
        name.to_s.sub(/_image_config\z/, "").to_sym
      end
    end
  end
end
