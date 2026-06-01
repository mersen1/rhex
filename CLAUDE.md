# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`rhex` is a pure-Ruby gem for hexagonal grids based on cube/axial coordinates. It provides
geometry (neighbors, distance, rings, line drawing), grid algorithms (path-finding, reachability,
field of view), and PNG rendering via RMagick. The math follows
https://www.redblobgames.com/grids/hexagons/.

## Commands

```shell
bundle install            # requires ImageMagick installed on the system (for rmagick)
bundle exec rspec         # run the full test suite
bundle exec rspec spec/lib/rhex/grid_spec.rb            # single file
bundle exec rspec spec/lib/rhex/grid_spec.rb:42         # single example by line
bundle exec rubocop       # lint (rubocop-shopify base config)
```

- Ruby 3.3.7 is required (see `.ruby-version` / Gemfile).
- The `Rakefile` declares a `rake/testtask` default, but tests are RSpec — use `bundle exec rspec`, not `rake test`.
- SimpleCov enforces **100% coverage**; the suite fails if any line is uncovered. New code must come with specs that exercise every branch.

## Architecture

### Coordinate model
- `Rhex::CubeHex` is the canonical hex: stores `q`, `r`, `s` plus optional `data` payload and
  `image_config` (validated by `Contracts::ImageConfigContract`). Equality and `hash` are
  coordinate-based, so hexes work as set members / hash keys.
- `Rhex::AxialHex` is a lightweight `(q, r)` form; convert with `to_cube` / `to_axial`.
- Every hex precomputes a `packed_key`: `(q << 32) | (r & 0xFFFFFFFF)` (see `CoordinatePacker.pack`).
  This single 64-bit integer is the hash key used everywhere for O(1) lookups — `s` is not part of the key.

### Grid as a coordinate-keyed store
- `Rhex::Grid` wraps a `@hash` keyed by `packed_key`. `add`/`<<`/`merge` overwrite by coordinate;
  `include?`, `size`, `to_a` give set-like semantics. Mutation is guarded by a `Mutex`.
- `Enumerable#to_grid` (monkey-patched) turns any hex collection into a `Grid`.

### Algorithms are injected, not inherited
This is the key architectural decision. `Grid` does **not** implement algorithms itself. Each algorithm
lives in its own class (`BfsPath`, `DfsPath`, `AstarPath`, `Reachable`, `FieldOfView`), and the grid
delegates to it. The grid takes a `grid_algorithms:` collaborator (default: the frozen singleton
`Rhex::GridAlgorithms::INSTANCE`) and forwards it into each algorithm class.

`GridAlgorithms` holds the shared primitives: `hex_distance`, `line_blocked?` (line-of-sight),
`obstacle_packed_key_set`, and `reconstruct_path_from_parents`.

When calling a grid algorithm, the grid takes a **snapshot** (`@hash.dup` under the mutex) and passes
it to a fresh algorithm instance — algorithms operate on an immutable view, never the live grid.
To test or swap behavior, pass a custom object via `Grid.new(hexes, grid_algorithms:)`.

### Path-finding semantics (shared error contract)
All three path methods raise `Grid::GridDoesNotContainSourceError` / `GridDoesNotContainTargetError`
when endpoints are missing, and `Grid::PathNotFoundError` when unreachable.
- `bfs_path` / `astar_path` return a shortest path (A\* explores fewer cells via a hex-distance heuristic + min-heap).
- `dfs_path` returns the first path found — **not** necessarily shortest.

### Rendering pipeline
- `Grid#to_pic` builds an **oriented grid** then delegates to `GridToPic`, which draws via RMagick and
  writes `images/<filename>.png` under the project root.
- Oriented grids (`FlatToppedGrid`, `PointyToppedGrid`) share `Concerns::OrientedGrid` and wrap each
  added hex in a screen-coordinate decorator (`Decorators::FlatToppedHex` / `PointyToppedHex`) computed
  from `hex_size`. `CanvasMarkups::AutoCanvasMarkup` centers the drawing.
- Pass `path:` (an ordered hex list, e.g. the result of `bfs_path`) to draw direction arrows between
  consecutive hexes via `Draw::Arrow`.
- The bundled Inconsolata font is always used for text; custom fonts are intentionally unsupported.

### Autoloading & conventions
- Files are autoloaded by Zeitwerk (`Zeitwerk::Loader.for_gem.setup` in `lib/rhex.rb`) — directory
  structure must match the module nesting (`lib/rhex/draw/arrow.rb` → `Rhex::Draw::Arrow`).
- Image configs are loaded from `*_config.yml` files via `ImageConfigs.load!(dir)` and fetched with
  `ImageConfigs.image_config_for(:key)` (filename `path_image_config.yml` → key `:path`).
- Some source comments are in Russian; keep this in mind when reading/grepping.
