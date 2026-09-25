# frozen_string_literal: true

module Rhex
  module CoordinatePacker
    MIN_32_BIT = -(1 << 31)
    MAX_32_BIT = (1 << 31) - 1
    WIDE_KEY_OFFSET = 1 << 64
    private_constant :MIN_32_BIT, :MAX_32_BIT, :WIDE_KEY_OFFSET

    # Packs axial (q, r) into a single integer key for O(1) hash lookups.
    # Only Integer coordinates can be packed — see Rhex::CubeHex#packed_key.
    def self.pack(q, r)
      unless q.is_a?(Integer) && r.is_a?(Integer)
        raise(ArgumentError, "Hex coordinates must be Integers, got: (#{q.inspect}, #{r.inspect})")
      end

      pack_unchecked(q, r)
    end

    # For callers that have already established Integer-ness — hex construction is hot enough
    # that the duplicate check is worth skipping there.
    def self.pack_unchecked(q, r)
      if q >= MIN_32_BIT && q <= MAX_32_BIT && r >= MIN_32_BIT && r <= MAX_32_BIT
        return (q << 32) | (r & 0xFFFFFFFF)
      end

      # The fast 64-bit layout aliases coordinates outside its signed 32-bit range. Use a
      # collision-free pairing for those coordinates, in a disjoint range of integer keys.
      unsigned_q = q >= 0 ? q * 2 : (-q * 2) - 1
      unsigned_r = r >= 0 ? r * 2 : (-r * 2) - 1
      sum = unsigned_q + unsigned_r
      WIDE_KEY_OFFSET + ((sum * (sum + 1)) / 2) + unsigned_r
    end
  end
end
