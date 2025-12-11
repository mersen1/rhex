# frozen_string_literal: true

require "ffi"
module Rhex
  module Native
    module Grid
      extend FFI::Library

      LIBRARY_BASENAME = "grid_native.#{FFI::Platform::LIBSUFFIX}"
      LIBRARY_PATH = File.expand_path(LIBRARY_BASENAME, __dir__)
      CUSTOM_LIBRARY_PATH = ENV["RHEX_NATIVE_LIB"] && File.expand_path(ENV["RHEX_NATIVE_LIB"])

      def self.native_library_path
        return @native_library_path if defined?(@native_library_path)

        # :nocov:
        if CUSTOM_LIBRARY_PATH
          unless File.exist?(CUSTOM_LIBRARY_PATH)
            raise("RHEX_NATIVE_LIB points to a missing file: #{CUSTOM_LIBRARY_PATH}")
          end

          @native_library_path = CUSTOM_LIBRARY_PATH
          return @native_library_path
        end

        unless File.exist?(LIBRARY_PATH)
          raise <<~MSG
            Native library not found at #{LIBRARY_PATH}.
            Build it manually (e.g. `cc -O3 -std=c99 -fPIC -shared grid_native.c -o #{LIBRARY_BASENAME}`)
            or set RHEX_NATIVE_LIB=/abs/path/to/#{LIBRARY_BASENAME}.
          MSG
        end
        # :nocov:

        @native_library_path = LIBRARY_PATH
      end

      ffi_lib native_library_path

      attach_function :reachable,
        [:pointer, :pointer, :int32, :int32, :int32, :int32, :pointer, :pointer, :int32, :pointer, :pointer, :int32],
        :int32

      attach_function :field_of_view,
        [:pointer, :pointer, :int32, :int32, :int32, :pointer, :pointer, :int32, :pointer, :pointer, :int32],
        :int32

      attach_function :bfs_path,
        [:pointer, :pointer, :int32, :int32, :int32, :int32, :int32, :pointer, :pointer, :int32, :pointer, :pointer, :int32],
        :int32

      attach_function :dfs_path,
        [:pointer, :pointer, :int32, :int32, :int32, :int32, :int32, :pointer, :pointer, :int32, :pointer, :pointer, :int32],
        :int32
    end
  end
end
