# Rhex
[![CI](https://github.com/mersen1/rhex/actions/workflows/ci.yml/badge.svg)](https://github.com/mersen1/rhex/actions/workflows/ci.yml)

Ruby toolkit for hexagonal grids based on cube/axial coordinates. It provides geometry utilities (neighbors, distance, reachability, rings, line drawing, path-finding) and rendering helpers that generate PNGs with RMagick. The implementation follows the concepts from https://www.redblobgames.com/grids/hexagons/.

## Requirements
- Ruby 3.3.7 or newer (tested against 3.3.7)
- ImageMagick installed on your system (needed for `rmagick`)
- Bundler for development/test tasks

## Installation
Use the Git source with Bundler:
```ruby
# Gemfile
gem "rhex", git: "https://github.com/mersen1/rhex.git"
```
Then install and require:
```shell
bundle install
```
```ruby
require "rhex"
```

## Quick start
```ruby
require "rhex"

origin = Rhex::AxialHex.new(0, 0)
grid   = origin.spiral_ring(2).to_grid # includes origin and rings up to radius 2

neighbors = origin.neighbors           # 6 surrounding hexes
distance  = origin.distance(Rhex::AxialHex.new(0, -2)) # => 2

# Render to images/sample_grid.png (centered automatically)
grid.to_pic("sample_grid", hex_size: 48, orientation: Rhex::GridToPic::POINTY_TOPPED)
```

## Core types
- `Rhex::CubeHex` – stores `q`, `r`, `s` coordinates plus optional `data` payload and optional `image_config` used for rendering.
- `Rhex::AxialHex` – lightweight wrapper around `CubeHex` that omits `s`; convert with `to_cube` / `to_axial`.
- Equality, `eql?`, and `hash` are coordinate based, so hexes with the same coordinates compare equal and work as hash keys.
- Reflection helpers: `reflection_q`, `reflection_r`, `reflection_s` reflect across the corresponding axes relative to an optional reference point.

## Spatial operations
- `neighbors(grid: nil)` – returns up to 6 neighbors. When a grid is provided, only neighbors that exist in the grid are returned; invalid direction indexes raise `NotInTheDirectionVectorsList`.
- `distance(other_hex)` – Manhattan distance in cube space.
- `reachable(movements_limit, obstacles: [])` – breadth-first expansion from the current hex, excluding obstacles; always includes the source hex.
- `ring(radius)` – all hexes exactly `radius` steps away.
- `spiral_ring(radius)` – concentric rings from radius 1..radius around the origin hex (raises `RadiusCannotBeZero` when radius is 0).
- `linedraw(target)` – interpolated straight line of hexes between two points.
- `field_of_view(grid, obstacles = [])` – hexes visible from the current hex that are not occluded along the line of sight.
- `dijkstra_shortest_path(target, grid, obstacles: [])` – returns the shortest path inside the given grid; raises if the source or target is missing from the grid and skips obstacles. When `Rhex::ImageConfigs.path_image_config` is loaded, returned hexes carry that image config for rendering.
- Utility math: include `Rhex::CubeHex::Math::Hexagon` to compute `movement_range(radius)` (number of reachable cells for a radius).

Example (path-finding with obstacles):
```ruby
grid      = Rhex::AxialHex.new(0, 0).spiral_ring(3).to_grid
source    = Rhex::AxialHex.new(0, 0)
target    = Rhex::AxialHex.new(2, -1)
obstacles = [Rhex::AxialHex.new(1, 0)]

path = source.dijkstra_shortest_path(target, grid, obstacles: obstacles)
```

## Working with grids
- `Rhex::Grid[]` builds a grid from hexes; duplicates are overwritten by coordinate (`q`, `r`).
- `#add`, `#merge`, `#include?`, `#exclude?`, `#size` behave like a set keyed on coordinates.
- `Enumerable#to_grid` converts any collection of hexes into a `Grid` (or a custom grid class via arguments).
- `#to_grid(klass, ...)` converts one grid into another grid implementation while reusing its contents.

## Oriented grids (for rendering)
- `Rhex::FlatToppedGrid` and `Rhex::PointyToppedGrid` decorate stored hexes to compute screen coordinates based on a `hex_size`.
- Each oriented grid exposes `#hex_size` and `#pointy_topped?`, and every added hex is wrapped in the appropriate decorator (`Rhex::Decorators::FlatToppedHex` or `Rhex::Decorators::PointyToppedHex`).

## Rendering to PNG
- Any grid can be rendered with `grid.to_pic("filename", hex_size: 64, orientation: Rhex::GridToPic::DEFAULT_ORIENTATION)`.
- The renderer:
  - Builds an oriented grid (`:flat_topped` by default) and centers it automatically using `CanvasMarkups::AutoCanvasMarkup`.
  - Draws each hex through `Rhex::Draw::Hexagon`, labeling it with its `q, r` coordinates.
  - Saves the image to `images/filename.png` inside the gem/project root.
- Default colors come from `Rhex::Draw::Hexagon::DEFAULT_IMAGE_CONFIG`. You can override per hex:
```ruby
config = Rhex::Draw::Hexagon::ImageConfig.new(
  hexagon: Rhex::Draw::Hexagon::ImageProperties.new(color: "#FFFACD", stroke_color: "#222222"),
  text:    Rhex::Draw::Hexagon::ImageProperties.new(color: "#333333", stroke_color: "none", font_size: 24)
)
hex = Rhex::AxialHex.new(0, 0, image_config: config)
[hex].to_grid.to_pic("custom_hex")
```

### Font selection
Rhex ships with a bundled Inconsolata font (`fonts/Inconsolata-Regular.ttf`) and always uses it when rendering text. Custom fonts are intentionally not supported; attempting to set a custom font path raises an error.

## Image configuration files
`Rhex::ImageConfigs.load!(path)` reads every `*_config.yml` in the given directory and defines readers named after each file (e.g., `path_image_config`). Each YAML entry is exposed as an `OpenStruct`, so keys like `hexagon.color`, `hexagon.stroke_color`, and `text.font_size` can be read by the renderer.

Example YAML (`path_image_config.yml`):
```yaml
hexagon:
  color: "#B3D5E6"
  stroke_color: "#B3B3B3"
text:
  color: "#000000"
  stroke_color: "none"
  font_size: 32
```
Usage:
```ruby
Rhex::ImageConfigs.load!(Rhex.root.join("config", "images"))
source = Rhex::AxialHex.new(0, 0, image_config: Rhex::ImageConfigs.source_image_config)
grid   = [source].to_grid
grid.to_pic("with_configs")
```

## Testing
The project uses RSpec with 100% coverage enforced by SimpleCov. Run the suite with:
```shell
bundle exec rspec
```

## Continuous integration
- GitHub Actions runs `bundle exec rspec` on every push and pull request to `master`.
- The badge at the top of this README links to the latest run results.
