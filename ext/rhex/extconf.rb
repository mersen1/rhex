# frozen_string_literal: true

require "mkmf"

$CFLAGS << " -std=c99 -Wall -Wextra -O3"

$srcs = Dir.glob("**/*.c").map { |path| File.basename(path) }

$VPATH << "$(srcdir)/grid"

create_makefile("rhex/rhex")
