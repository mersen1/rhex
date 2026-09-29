# frozen_string_literal: true

require "mkmf"

# Ruby evaluates multiplication and addition separately. Fusing them can change
# rounding at hex borders on FMA-capable targets (including ARM64).
append_cflags("-ffp-contract=off")

create_makefile("rhex/native_ext")
