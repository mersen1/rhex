# frozen_string_literal: true

module Rhex
  module CoordinatePacker
    # Packs axial (q, r) into a single 64-bit integer key for O(1) hash lookups.
    # Only Integer coordinates can be packed — see Rhex::CubeHex#packed_key.
    def self.pack(q, r)
      unless q.is_a?(Integer) && r.is_a?(Integer)
        raise(ArgumentError, "Hex coordinates must be Integers, got: (#{q.inspect}, #{r.inspect})")
      end

      (q << 32) | (r & 0xFFFFFFFF)
    end
  end
end
