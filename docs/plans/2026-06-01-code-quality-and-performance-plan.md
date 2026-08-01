# Rhex Code Quality & Performance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor Rhex gem for better encapsulation, lower memory usage, faster validation, and A\* pathfinding — without breaking the public API.

**Architecture:** Six parallel improvements: (1) `AxialHex` inheritance, (2) `Grid` Mutex + internal interface, (3) algorithm classes decouple from Grid, (4) memory reductions, (5) duplication removal, (6) A\* with binary min-heap.

**Tech Stack:** Ruby 3.3.7, RSpec, dry-validation, RMagick. No new runtime deps added.

**Design doc:** `docs/plans/2026-06-01-code-quality-and-performance-design.md`

---

## Task 1: `AxialHex` → Inherit from `CubeHex`

**Files:**
- Modify: `lib/rhex/axial_hex.rb`
- Test: `spec/lib/rhex/axial_hex_spec.rb`

**Step 1: Run existing spec to capture baseline**

```bash
bundle exec rspec spec/lib/rhex/axial_hex_spec.rb -f doc
```

Expected: all pass. Note what behaviors are tested.

**Step 2: Modify `axial_hex.rb`**

Replace entire file:

```ruby
# frozen_string_literal: true

module Rhex
  class AxialHex < CubeHex
    def initialize(q, r, data: nil, image_config: nil)
      super(q, r, -q - r, data: data, image_config: image_config)
    end

    def to_cube
      CubeHex.new(q, r, s, data: data, image_config: image_config)
    end
  end
end
```

**Step 3: Simplify `Grid#add` type check**

In `lib/rhex/grid.rb`, find the `add` method. Change:

```ruby
# before
unless hex.is_a?(Rhex::CubeHex) || hex.is_a?(Rhex::AxialHex)
  raise(ArgumentError, "Only Rhex::CubeHex or Rhex::AxialHex instances can be added to the grid, got: #{hex.class}")
end
```

```ruby
# after
unless hex.is_a?(Rhex::CubeHex)
  raise(ArgumentError, "Only Rhex::CubeHex or Rhex::AxialHex instances can be added to the grid, got: #{hex.class}")
end
```

The message stays the same for user clarity.

**Step 4: Run specs**

```bash
bundle exec rspec spec/lib/rhex/axial_hex_spec.rb spec/lib/rhex/grid_spec.rb -f doc
```

Expected: all pass. If `to_cube` specs check object identity (`equal?`), update to check value equality (`==`) — `to_cube` now returns a new object.

**Step 5: Run full suite**

```bash
bundle exec rspec
```

Expected: all pass.

**Step 6: Commit**

```bash
git add lib/rhex/axial_hex.rb lib/rhex/grid.rb spec/lib/rhex/axial_hex_spec.rb
git commit -m "refactor: AxialHex inherits CubeHex instead of SimpleDelegator"
```

---

## Task 2: `Grid` — Add `Mutex` + Protected `grid_hash` Accessor

**Files:**
- Modify: `lib/rhex/grid.rb`
- Test: `spec/lib/rhex/grid_spec.rb`

**Step 1: Add Mutex to `Grid#initialize`**

In `lib/rhex/grid.rb`, update `initialize`:

```ruby
def initialize(hexes = nil, grid_algorithms: GridAlgorithms::INSTANCE)
  @grid_algorithms = grid_algorithms
  @mutex = Mutex.new
  @hash = {}

  return if hexes.nil?

  hexes.each { add(_1) }
end
```

**Step 2: Protect `add` with Mutex**

```ruby
def add(hex)
  unless hex.is_a?(Rhex::CubeHex)
    raise(
      ArgumentError,
      "Only Rhex::CubeHex or Rhex::AxialHex instances can be added to the grid, got: #{hex.class}"
    )
  end

  @mutex.synchronize { @hash[key(hex)] = hex }
  self
end
```

**Step 3: Protect `merge` with Mutex**

```ruby
def merge(other)
  @mutex.synchronize do
    if other.instance_of?(self.class)
      @hash.update(other.instance_variable_get(:@hash))
    else
      other.each { |hex| @hash[key(hex)] = hex }
    end
  end
  self
end
```

Note: `merge` uses `instance_variable_get` on `other` which is a Grid — this is acceptable since it's the same class. We'll clean this up when we add `grid_hash`.

**Step 4: Add protected `grid_hash` accessor**

At the bottom of `Grid`, inside the `private` section (add a `protected` block above `private`):

```ruby
protected

def grid_hash = @hash

private

def key(hex)
  ...
end
```

**Step 5: Fix `merge` to use `grid_hash`**

Now update `merge` to use the protected accessor instead of `instance_variable_get`:

```ruby
def merge(other)
  @mutex.synchronize do
    if other.instance_of?(self.class)
      @hash.update(other.send(:grid_hash))
    else
      other.each { |hex| @hash[key(hex)] = hex }
    end
  end
  self
end
```

> **Important — do NOT touch the algorithm methods yet.** In this task the algorithm
> classes (`Reachable`, `BfsPath`, `DfsPath`, `FieldOfView`) still expect a `Grid`
> object and read it via `grid.instance_variable_get(:@hash)`. Leave
> `reachable` / `field_of_view` / `bfs_path` / `dfs_path` passing `self` unchanged.
> The snapshot switch happens in **Task 3**, after the algorithm classes are taught
> to accept a plain Hash. Switching here would pass a `Hash` to classes that call
> `instance_variable_get` on it (returning `nil`), breaking every algorithm spec.

**Step 6: Run specs**

```bash
bundle exec rspec spec/lib/rhex/grid_spec.rb -f doc
```

Expected: all pass (algorithms still receive `self`, only `add`/`merge` are now Mutex-protected).

**Step 7: Commit**

```bash
git add lib/rhex/grid.rb
git commit -m "refactor: add Mutex to Grid writes; add protected grid_hash accessor"
```

---

## Task 3: Algorithm Classes — Accept `grid_hash` Directly

Update `BfsPath`, `DfsPath`, `Reachable`, `FieldOfView` to accept a plain Hash instead of a `Grid` object.

**Files:**
- Modify: `lib/rhex/bfs_path.rb`
- Modify: `lib/rhex/dfs_path.rb`
- Modify: `lib/rhex/reachable.rb`
- Modify: `lib/rhex/field_of_view.rb`

### BfsPath

**Step 1: Update `BfsPath#initialize`**

```ruby
def initialize(grid_hash, obstacles: [], grid_algorithms: GridAlgorithms::INSTANCE)
  @grid_hash = grid_hash
  @obstacles = obstacles
  @grid_algorithms = grid_algorithms
end
```

**Step 2: Update `BfsPath#call`**

Remove the line:
```ruby
grid_hash = grid.instance_variable_get(:@hash)
```

Replace `grid_hash` references — already a local name, so the method body stays the same. Remove `attr_reader :grid` from `private`.

Final `private` section:
```ruby
private

attr_reader :grid_hash, :obstacles, :grid_algorithms
```

### DfsPath

Same changes as BfsPath. Remove `grid.instance_variable_get(:@hash)` line; use `@grid_hash` directly; update `initialize`; update `attr_reader`.

### Reachable

Same pattern.

### FieldOfView

Same pattern. Note `FieldOfView#call` uses `grid_hash.each_with_object` — works the same on a plain Hash.

**Step 3: Switch `Grid` algorithm methods to pass a Mutex-guarded snapshot**

Now that the algorithm classes accept a plain Hash, update all four methods in
`lib/rhex/grid.rb` to pass a consistent snapshot taken under the Mutex (added in Task 2):

```ruby
def reachable(source, movements_limit = 1, obstacles: [])
  snapshot = @mutex.synchronize { @hash.dup }
  Reachable.new(snapshot, obstacles: obstacles, grid_algorithms: @grid_algorithms).call(source, movements_limit)
end

def field_of_view(source, obstacles: [])
  snapshot = @mutex.synchronize { @hash.dup }
  FieldOfView.new(snapshot, obstacles: obstacles, grid_algorithms: @grid_algorithms).call(source)
end

def bfs_path(source, target, obstacles: [])
  snapshot = @mutex.synchronize { @hash.dup }
  BfsPath.new(snapshot, obstacles: obstacles, grid_algorithms: @grid_algorithms).call(source, target)
end

def dfs_path(source, target, obstacles: [])
  snapshot = @mutex.synchronize { @hash.dup }
  DfsPath.new(snapshot, obstacles: obstacles, grid_algorithms: @grid_algorithms).call(source, target)
end
```

This is the only point where it is safe to make the switch: the classes and the
caller change together, so the suite stays green.

**Step 4: Run specs**

```bash
bundle exec rspec spec/lib/rhex/bfs_path_spec.rb spec/lib/rhex/dfs_path_spec.rb spec/lib/rhex/grid_spec.rb -f doc
```

Expected: all pass.

**Step 5: Run full suite**

```bash
bundle exec rspec
```

**Step 6: Commit**

```bash
git add lib/rhex/bfs_path.rb lib/rhex/dfs_path.rb lib/rhex/reachable.rb lib/rhex/field_of_view.rb lib/rhex/grid.rb
git commit -m "refactor: algorithm classes accept grid_hash directly; Grid passes snapshot"
```

---

## Task 4: `Reachable` — Merge `visited` into `distance_map`

**Files:**
- Modify: `lib/rhex/reachable.rb`
- Test: `spec/lib/rhex/` (reachable tests are in grid_spec or separate)

**Step 1: Remove `visited` hash from `Reachable#call`**

In `lib/rhex/reachable.rb`, remove:
```ruby
visited = { start_packed_key => true }
```

Replace every occurrence of:
```ruby
next if ... || visited.key?(neighbor_packed_key)
visited[neighbor_packed_key] = true
```

With:
```ruby
next if ... || distance_map.key?(neighbor_packed_key)
# (no separate visited assignment needed)
```

The `distance_map[neighbor_packed_key] = next_dist` line already marks it as visited.

The complete updated inner loop:

```ruby
Constants::AXIAL_NEIGHBOR_DELTAS.each do |dq, dr|
  neighbor_packed_key = CoordinatePacker.pack(current.q + dq, current.r + dr)

  next if obstacle_set.key?(neighbor_packed_key) || distance_map.key?(neighbor_packed_key)

  n_hex = grid_hash[neighbor_packed_key]
  next unless n_hex

  distance_map[neighbor_packed_key] = next_dist
  result << n_hex
  queue << n_hex
end
```

**Step 2: Run specs**

```bash
bundle exec rspec spec/lib/rhex/grid_spec.rb -f doc
```

Look for reachable-related tests. All must pass.

**Step 3: Commit**

```bash
git add lib/rhex/reachable.rb
git commit -m "perf: Reachable uses single distance_map, removes redundant visited hash"
```

---

## Task 5: `Constants` — Add `DEG_TO_RAD`

**Files:**
- Modify: `lib/rhex/constants.rb`
- Modify: `lib/rhex/canvas_markups/auto_canvas_markup.rb`
- Modify: `lib/rhex/draw/hexagon.rb`
- Test: `spec/lib/rhex/constants_spec.rb`

**Step 1: Add `DEG_TO_RAD` to `Constants`**

In `lib/rhex/constants.rb`, add:

```ruby
DEG_TO_RAD = (Math::PI / 180.0).freeze
```

**Step 2: Update `AutoCanvasMarkup`**

Remove:
```ruby
DEG_TO_RAD = Math::PI / 180.0
```

Add at top of relevant methods or reference via:
```ruby
rad = deg * Rhex::Constants::DEG_TO_RAD
```

**Step 3: Update `Draw::Hexagon`**

Same — remove local `DEG_TO_RAD` constant, reference `Rhex::Constants::DEG_TO_RAD`.

**Step 4: Run specs**

```bash
bundle exec rspec spec/lib/rhex/constants_spec.rb spec/lib/rhex/draw/hexagon_spec.rb spec/lib/rhex/canvas_markups/ -f doc
```

**Step 5: Commit**

```bash
git add lib/rhex/constants.rb lib/rhex/canvas_markups/auto_canvas_markup.rb lib/rhex/draw/hexagon.rb
git commit -m "refactor: move DEG_TO_RAD to Constants, remove duplication"
```

---

## Task 6: `Draw::Hexagon` — Cache Validated Default Config

**Files:**
- Modify: `lib/rhex/draw/hexagon.rb`
- Test: `spec/lib/rhex/draw/hexagon_spec.rb`

**Step 1: Write failing test (behavioral, no over-mocking)**

Follow the existing style in `spec/lib/rhex/draw/hexagon_spec.rb` — use a real
decorated hex and a thin `Magick::Draw` double. Do NOT stub `:class` / `:coordinates`
or fake the contract result; assert observable behavior instead.

Add to `spec/lib/rhex/draw/hexagon_spec.rb`:

```ruby
describe "default config validation" do
  let(:hex) { Rhex::Decorators::FlatToppedHex.new(Rhex::AxialHex.new(0, 0), size: 2) }
  let(:gc) do
    instance_double(Magick::Draw, fill: nil, stroke: nil, polygon: nil, font_size: nil, text: nil)
  end

  it "does not run the contract when using the cached default config" do
    allow(Rhex::Contracts::ImageConfigContract).to receive(:new).and_call_original

    3.times { described_class.new(gc: gc, hex: hex) }

    expect(Rhex::Contracts::ImageConfigContract).not_to have_received(:new)
  end

  it "still validates an explicitly provided default_image_config" do
    invalid = { hexagon: { color: "#fff" }, text: {} }

    expect do
      described_class.new(gc: gc, hex: hex, default_image_config: invalid)
    end.to raise_error(ArgumentError)
  end
end
```

The first example is the failing/red one (current code runs the contract on every
instantiation, including for the default). The second guards that a non-default
config is still validated.

**Step 2: Run tests to verify the first fails**

```bash
bundle exec rspec spec/lib/rhex/draw/hexagon_spec.rb -e "default config validation" -f doc
```

Expected: the "cached default config" example FAILS (Contract is currently called
per instantiation); the "explicitly provided" example passes.

**Step 3: Add `VALIDATED_DEFAULT_IMAGE_CONFIG` to `Hexagon`**

In `lib/rhex/draw/hexagon.rb`, after `DEFAULT_IMAGE_CONFIG`:

```ruby
VALIDATED_DEFAULT_IMAGE_CONFIG = begin
  result = Rhex::Contracts::ImageConfigContract.new.call(DEFAULT_IMAGE_CONFIG)
  raise(ArgumentError, "Invalid DEFAULT_IMAGE_CONFIG: #{result.errors.to_h}") if result.failure?
  result.to_h.freeze
end
private_constant :VALIDATED_DEFAULT_IMAGE_CONFIG
```

Update `initialize`:

```ruby
def initialize(gc:, hex:, default_image_config: VALIDATED_DEFAULT_IMAGE_CONFIG)
  @gc = gc
  @hex = hex
  @default_image_config = if default_image_config.equal?(VALIDATED_DEFAULT_IMAGE_CONFIG)
    default_image_config
  else
    validation = Rhex::Contracts::ImageConfigContract.new.call(default_image_config)
    raise(ArgumentError, "Invalid image_config: #{validation.errors.to_h}") if validation.failure?
    validation.to_h
  end
end
```

**Step 4: Run test**

```bash
bundle exec rspec spec/lib/rhex/draw/hexagon_spec.rb -f doc
```

Expected: all pass.

**Step 5: Commit**

```bash
git add lib/rhex/draw/hexagon.rb spec/lib/rhex/draw/hexagon_spec.rb
git commit -m "perf: cache validated DEFAULT_IMAGE_CONFIG in Draw::Hexagon at class load"
```

---

## Task 7: `AutoCanvasMarkup` — Bounding Box Without Vertex Materialization

**Files:**
- Modify: `lib/rhex/canvas_markups/auto_canvas_markup.rb`
- Test: `spec/lib/rhex/canvas_markups/auto_canvas_markup_spec.rb`

**Step 1: Run existing spec**

```bash
bundle exec rspec spec/lib/rhex/canvas_markups/auto_canvas_markup_spec.rb -f doc
```

Note all passing examples.

**Step 2: Replace `vertices` + x/y min/max methods**

Remove these private methods from `AutoCanvasMarkup`:
- `vertices`
- `polygon_vertices`
- `x_min`, `x_max`, `y_min`, `y_max`

Replace with a single `bounding_box` method:

```ruby
def bounding_box
  @bounding_box ||= begin
    x_min = Float::INFINITY
    x_max = -Float::INFINITY
    y_min = Float::INFINITY
    y_max = -Float::INFINITY

    grid.each do |hex|
      hx = hex.coordinates.x
      hy = hex.coordinates.y
      hw = hex.width / 2.0
      hh = hex.height / 2.0

      xlo = hx - hw
      xhi = hx + hw
      ylo = hy - hh
      yhi = hy + hh

      x_min = xlo if xlo < x_min
      x_max = xhi if xhi > x_max
      y_min = ylo if ylo < y_min
      y_max = yhi if yhi > y_max
    end

    { x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max }
  end
end
```

Update references in `width`, `height`, `bounding_center` etc.:

```ruby
def width
  @width ||= span_with_stroke(bounding_box[:x_max] - bounding_box[:x_min])
end

def height
  @height ||= span_with_stroke(bounding_box[:y_max] - bounding_box[:y_min])
end

def bounding_center
  @bounding_center ||= Center.new(
    x: (x_min_with_stroke + x_max_with_stroke) / 2.0,
    y: (y_min_with_stroke + y_max_with_stroke) / 2.0
  )
end

def x_min_with_stroke = bounding_box[:x_min] - STROKE_WIDTH / 2.0
def x_max_with_stroke = bounding_box[:x_max] + STROKE_WIDTH / 2.0
def y_min_with_stroke = bounding_box[:y_min] - STROKE_WIDTH / 2.0
def y_max_with_stroke = bounding_box[:y_max] + STROKE_WIDTH / 2.0
```

**Step 3: Run specs**

```bash
bundle exec rspec spec/lib/rhex/canvas_markups/auto_canvas_markup_spec.rb spec/lib/rhex/grid_to_pic_spec.rb -f doc
```

Expected: all pass. The public interface (`width`, `height`, `center`) is unchanged.

**Step 4: Commit**

```bash
git add lib/rhex/canvas_markups/auto_canvas_markup.rb
git commit -m "perf: AutoCanvasMarkup computes bounding box directly, avoids 6n vertex objects"
```

---

## Task 8: Extract `BaseOrientedHex` Decorator

**Files:**
- Create: `lib/rhex/decorators/base_oriented_hex.rb`
- Modify: `lib/rhex/decorators/flat_topped_hex.rb`
- Modify: `lib/rhex/decorators/pointy_topped_hex.rb`
- Modify: `lib/rhex.rb` (autoload)
- Test: `spec/lib/rhex/decorators/flat_topped_hex_spec.rb`
- Test: `spec/lib/rhex/decorators/pointy_topped_hex_spec.rb`

**Step 1: Create `base_oriented_hex.rb`**

```ruby
# frozen_string_literal: true

module Rhex
  module Decorators
    class BaseOrientedHex < SimpleDelegator
      Coordinates = Struct.new(:x, :y, keyword_init: true)
      private_constant :Coordinates

      def initialize(obj, size:)
        super(obj)
        @size = size
      end

      attr_reader :size

      def coordinates
        @coordinates ||= Coordinates.new(x: coordinate_x, y: coordinate_y)
      end

      def radius
        (2.0 / Math.sqrt(3)) * size
      end

      private

      def coordinate_x
        raise(NotImplementedError, "#{self.class}#coordinate_x is not implemented")
      end

      def coordinate_y
        raise(NotImplementedError, "#{self.class}#coordinate_y is not implemented")
      end
    end
  end
end
```

**Step 2: Update `FlatToppedHex`**

```ruby
# frozen_string_literal: true

module Rhex
  module Decorators
    class FlatToppedHex < BaseOrientedHex
      ANGLES = [0, 60, 120, 180, 240, 300].freeze

      def height
        (3.0 / 2.0) * radius
      end

      def width
        Math.sqrt(3) * radius
      end

      private

      def coordinate_x
        width * 3 / 4 * q
      end

      def coordinate_y
        height * (r + (q / 2.0))
      end
    end
  end
end
```

**Step 3: Update `PointyToppedHex`**

```ruby
# frozen_string_literal: true

module Rhex
  module Decorators
    class PointyToppedHex < BaseOrientedHex
      ANGLES = [30, 90, 150, 210, 270, 330].freeze

      def height
        Math.sqrt(3) * radius
      end

      def width
        (3.0 / 2.0) * radius
      end

      private

      def coordinate_x
        width * (q + (r / 2.0))
      end

      def coordinate_y
        height * 3 / 4 * r
      end
    end
  end
end
```

**Step 4: Autoload — no action needed**

`lib/rhex.rb` uses `Zeitwerk::Loader.for_gem.setup`. The file naming convention
(`decorators/base_oriented_hex.rb` → `Rhex::Decorators::BaseOrientedHex`) is picked
up automatically, and `FlatToppedHex < BaseOrientedHex` triggers the autoload when
referenced. **Do not edit `lib/rhex.rb`** — there is no require list to update.

**Step 5: Run specs**

```bash
bundle exec rspec spec/lib/rhex/decorators/ -f doc
```

Expected: all pass.

**Step 6: Commit**

```bash
git add lib/rhex/decorators/base_oriented_hex.rb lib/rhex/decorators/flat_topped_hex.rb lib/rhex/decorators/pointy_topped_hex.rb
git commit -m "refactor: extract BaseOrientedHex, remove duplication between hex decorators"
```

---

## Task 9: Remove `Object.const_get` from Grid Classes

**Files:**
- Modify: `lib/rhex/flat_topped_grid.rb`
- Modify: `lib/rhex/pointy_topped_grid.rb`

**Step 1: Update `FlatToppedGrid`**

Remove:
```ruby
FLAT_TOPPED_HEX_CLASS_NAME = "Rhex::Decorators::FlatToppedHex"
private_constant :FLAT_TOPPED_HEX_CLASS_NAME

def hex_decorator_class
  Object.const_get(FLAT_TOPPED_HEX_CLASS_NAME)
end
```

Replace with:
```ruby
def hex_decorator_class
  Rhex::Decorators::FlatToppedHex
end
```

**Step 2: Same for `PointyToppedGrid`**

```ruby
def hex_decorator_class
  Rhex::Decorators::PointyToppedHex
end
```

**Step 3: Run specs**

```bash
bundle exec rspec spec/lib/rhex/flat_topped_grid_spec.rb spec/lib/rhex/pointy_topped_grid_spec.rb -f doc
```

**Step 4: Commit**

```bash
git add lib/rhex/flat_topped_grid.rb lib/rhex/pointy_topped_grid.rb
git commit -m "refactor: reference decorator classes directly instead of Object.const_get"
```

---

## Task 10: `ImageConfigs` — YAML Fix + Remove `activesupport`

**Files:**
- Modify: `lib/rhex/image_configs.rb`
- Modify: `rhex.gemspec`
- Test: `spec/lib/rhex/image_configs_spec.rb`

**Step 1: Check activesupport usage**

Search for `with_indifferent_access` and `ActiveSupport` in the codebase:

```bash
grep -rn "with_indifferent_access\|ActiveSupport" lib/ spec/
```

If found only in `image_configs.rb` — safe to remove.

**Step 2: Update `load_file!`**

In `lib/rhex/image_configs.rb`, replace:
```ruby
config = JSON.parse(YAML.safe_load(File.read(file_path)).to_json).with_indifferent_access
```

With:
```ruby
config = YAML.safe_load(File.read(file_path), symbolize_names: true)
```

**Step 3: Check downstream usage**

`image_config_for` returns the config object. Check if callers use string keys or symbol keys. The `ImageConfigContract` in `CubeHex#image_config=` uses dry-validation which handles both. Verify:

```bash
grep -rn "image_config_for\|image_config\[" lib/ spec/
```

The contract uses `params` block which coerces keys — should be fine with symbolized keys.

**Step 4: Remove `activesupport` from gemspec**

In `rhex.gemspec`, remove:
```ruby
s.add_dependency("activesupport")
```

Also remove any `require "active_support"` or `require "active_support/core_ext"` lines if present.

**Step 5: Remove `require "json"` if no longer needed**

Check if `JSON` is used elsewhere:
```bash
grep -rn "JSON\." lib/
```

If only in `image_configs.rb`, remove the require (or it may be in stdlib auto-require).

**Step 6: Run specs**

```bash
bundle exec rspec spec/lib/rhex/image_configs_spec.rb -f doc
```

**Step 7: Run full suite**

```bash
bundle exec rspec
```

**Step 8: Commit**

```bash
git add lib/rhex/image_configs.rb rhex.gemspec
git commit -m "refactor: YAML.safe_load with symbolize_names, remove activesupport dependency"
```

---

## Task 11: `AstarPath` with Binary Min-Heap

**Files:**
- Create: `lib/rhex/astar_path.rb`
- Modify: `lib/rhex/grid.rb` (add `astar_path` method)
- Modify: `lib/rhex.rb` (autoload)
- Create: `spec/lib/rhex/astar_path_spec.rb`

**Step 1: Write failing spec**

Create `spec/lib/rhex/astar_path_spec.rb`:

> **Note on helpers.** There is no `axial(...)` helper in `spec/support/` — the
> existing helpers are `coords_to_hexes`, `grid(range)`, `square_grid(range)`. Do
> NOT `include GridHelpers` here: its `grid(range)` method clashes with the
> `let(:grid)` below. We define a tiny local `axial` helper instead.

```ruby
# frozen_string_literal: true

require "spec_helper"

RSpec.describe Rhex::AstarPath do
  def axial(q, r) = Rhex::AxialHex.new(q, r)

  let(:grid) { Rhex::AxialHex.new(0, 0).spiral_ring(3).to_grid }

  describe "#call" do
    context "when path exists" do
      it "returns the shortest path from source to target" do
        source = grid[axial(0, 0)]
        target = grid[axial(2, -1)]

        path = grid.astar_path(source, target)

        expect(path.first).to eq(source)
        expect(path.last).to eq(target)
        expect(path.length).to eq(grid.bfs_path(source, target).length)
      end
    end

    context "when path is blocked by obstacles" do
      it "routes around obstacles" do
        source = grid[axial(0, 0)]
        target = grid[axial(2, 0)]
        obstacle = axial(1, 0)

        path = grid.astar_path(source, target, obstacles: [obstacle])

        expect(path).not_to include(obstacle)
        expect(path.first).to eq(source)
        expect(path.last).to eq(target)
      end
    end

    context "when source equals target" do
      it "returns a single-element path" do
        source = grid[axial(0, 0)]

        path = grid.astar_path(source, source)

        expect(path).to eq([source])
      end
    end

    context "when path does not exist" do
      it "raises PathNotFoundError" do
        small_grid = Rhex::Grid[axial(0, 0), axial(3, 0)]
        source = small_grid[axial(0, 0)]
        target = small_grid[axial(3, 0)]

        expect { small_grid.astar_path(source, target) }.to raise_error(Rhex::Grid::PathNotFoundError)
      end
    end

    context "when source is not in grid" do
      it "raises GridDoesNotContainSourceError" do
        source = axial(99, 99)
        target = grid[axial(0, 0)]

        expect { grid.astar_path(source, target) }.to raise_error(Rhex::Grid::GridDoesNotContainSourceError)
      end
    end

    context "when target is not in grid" do
      it "raises GridDoesNotContainTargetError" do
        source = grid[axial(0, 0)]
        target = axial(99, 99)

        expect { grid.astar_path(source, target) }.to raise_error(Rhex::Grid::GridDoesNotContainTargetError)
      end
    end
  end
end
```

**Step 2: Run spec to verify it fails**

```bash
bundle exec rspec spec/lib/rhex/astar_path_spec.rb -f doc
```

Expected: FAIL with `undefined method 'astar_path'`.

**Step 3: Create `lib/rhex/astar_path.rb`**

```ruby
# frozen_string_literal: true

module Rhex
  class AstarPath
    class MinHeap
      def initialize = @heap = []
      def empty? = @heap.empty?

      def push(priority, payload)
        @heap << [priority, payload]
        sift_up(@heap.size - 1)
      end

      def pop
        swap(0, @heap.size - 1)
        min = @heap.pop
        sift_down(0) unless @heap.empty?
        min
      end

      private

      def sift_up(i)
        while i > 0
          parent = (i - 1) / 2
          break if @heap[parent][0] <= @heap[i][0]

          swap(parent, i)
          i = parent
        end
      end

      def sift_down(i)
        n = @heap.size
        loop do
          s = i
          l = 2 * i + 1
          r = 2 * i + 2
          s = l if l < n && @heap[l][0] < @heap[s][0]
          s = r if r < n && @heap[r][0] < @heap[s][0]
          break if s == i

          swap(s, i)
          i = s
        end
      end

      def swap(i, j) = @heap[i], @heap[j] = @heap[j], @heap[i]
    end

    private_constant :MinHeap

    def initialize(grid_hash, obstacles: [], grid_algorithms: GridAlgorithms::INSTANCE)
      @grid_hash = grid_hash
      @obstacles = obstacles
      @grid_algorithms = grid_algorithms
    end

    def call(source, target)
      ga = grid_algorithms

      start_q = source.q
      start_r = source.r
      target_q = target.q
      target_r = target.r

      start_packed_key = CoordinatePacker.pack(start_q, start_r)
      target_packed_key = CoordinatePacker.pack(target_q, target_r)

      start_hex = grid_hash[start_packed_key]
      raise Grid::GridDoesNotContainSourceError unless start_hex
      raise Grid::GridDoesNotContainTargetError unless grid_hash[target_packed_key]
      return [start_hex] if start_packed_key == target_packed_key

      obstacle_set = ga.obstacle_packed_key_set(obstacles)
      g_scores = { start_packed_key => 0 }
      parents = {}

      open_list = MinHeap.new
      open_list.push(ga.hex_distance(start_q, start_r, target_q, target_r), [0, start_packed_key, start_hex])

      until open_list.empty?
        _, (g, current_packed_key, current) = open_list.pop

        # Lazy deletion: skip stale entries
        next if g_scores.fetch(current_packed_key, Float::INFINITY) < g

        if current_packed_key == target_packed_key
          return ga.reconstruct_path_from_parents(grid_hash, parents, start_packed_key, target_packed_key)
        end

        cq = current.q
        cr = current.r

        Constants::AXIAL_NEIGHBOR_DELTAS.each do |dq, dr|
          nq = cq + dq
          nr = cr + dr
          neighbor_packed_key = CoordinatePacker.pack(nq, nr)

          next if obstacle_set.key?(neighbor_packed_key)

          n_hex = grid_hash[neighbor_packed_key]
          next unless n_hex

          new_g = g + 1
          next if g_scores.key?(neighbor_packed_key) && g_scores[neighbor_packed_key] <= new_g

          g_scores[neighbor_packed_key] = new_g
          parents[neighbor_packed_key] = current_packed_key

          f = new_g + ga.hex_distance(nq, nr, target_q, target_r)
          open_list.push(f, [new_g, neighbor_packed_key, n_hex])
        end
      end

      raise Grid::PathNotFoundError
    end

    private

    attr_reader :grid_hash, :obstacles, :grid_algorithms
  end
end
```

**Step 4: Add `astar_path` to `Grid`**

In `lib/rhex/grid.rb`, add after `dfs_path`:

```ruby
def astar_path(source, target, obstacles: [])
  snapshot = @mutex.synchronize { @hash.dup }
  AstarPath.new(snapshot, obstacles: obstacles, grid_algorithms: @grid_algorithms).call(source, target)
end
```

**Step 5: Autoload — no action needed**

`lib/rhex.rb` uses `Zeitwerk::Loader.for_gem.setup`, so `lib/rhex/astar_path.rb` →
`Rhex::AstarPath` autoloads by convention. **Do not edit `lib/rhex.rb`.**

**Step 6: Run spec**

```bash
bundle exec rspec spec/lib/rhex/astar_path_spec.rb -f doc
```

Expected: all pass.

**Step 7: Run full suite**

```bash
bundle exec rspec
```

**Step 8: Commit**

```bash
git add lib/rhex/astar_path.rb lib/rhex/grid.rb spec/lib/rhex/astar_path_spec.rb
git commit -m "feat: add AstarPath with binary min-heap; expose as grid.astar_path"
```

---

## Task 12: Final Verification

**Step 1: Run Rubocop**

```bash
bundle exec rubocop --autocorrect
```

Review any non-auto-fixed offenses. Common issues to watch:
- Method length in `AstarPath#call` — may need to extract helpers
- Protected method ordering in `Grid`

**Step 2: Run full RSpec suite with coverage**

```bash
bundle exec rspec --format documentation
```

Expected: all green.

**Step 3: Check gem loads cleanly**

```bash
bundle exec ruby -e "require 'rhex'; puts Rhex::VERSION rescue puts 'OK'"
```

**Step 4: Final commit**

```bash
git add -A
git commit -m "chore: rubocop fixes after refactoring"
```

---

## Verification Checklist

- [ ] `AxialHex < CubeHex` — no SimpleDelegator
- [ ] `Grid#add` uses `Mutex`
- [ ] `Grid#bfs_path` / `dfs_path` / `reachable` / `field_of_view` / `astar_path` pass snapshots
- [ ] Algorithm classes accept `grid_hash` (plain Hash), no `instance_variable_get`
- [ ] `Reachable` has single tracking hash (`distance_map` only)
- [ ] `AutoCanvasMarkup` computes bounds without `vertices` array
- [ ] `Draw::Hexagon` validates default config only once (class level)
- [ ] `DEG_TO_RAD` only in `Constants`
- [ ] `BaseOrientedHex` exists; `FlatToppedHex`/`PointyToppedHex` inherit from it
- [ ] No `Object.const_get` in grid classes
- [ ] `ImageConfigs` uses `YAML.safe_load(symbolize_names: true)`
- [ ] `activesupport` removed from gemspec
- [ ] `AstarPath` with `MinHeap` added and spec'd
- [ ] All specs green
- [ ] Rubocop clean
