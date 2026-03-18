# frozen_string_literal: true

module Rhex
  module CoordinatePacker
    # Packs axial (q, r) into a single 64-bit integer key for O(1) hash lookups.
    def self.pack(q, r)
      (q << 32) | (r & 0xFFFFFFFF)
    end
  end
end
