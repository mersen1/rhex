# Rhex — Code Quality & Performance Design

**Date:** 2026-06-01  
**Scope:** Full structural refactoring — encapsulation, memory, validation performance, A\*

---

## Context

Rhex is a Ruby gem for hexagonal grids (cube/axial coordinates) with pathfinding, field-of-view, reachability, and RMagick-based rendering. Six areas were identified for improvement through analysis of all 22 library files.

---

## Section 1: `AxialHex` — Inheritance Instead of Delegation

**Current:** `AxialHex < SimpleDelegator` wraps a `CubeHex` internally. Every `AxialHex.new(q, r)` allocates two objects: the delegator and the inner `CubeHex`.

**Design:** Make `AxialHex < CubeHex` directly.

```ruby
class AxialHex < CubeHex
  def initialize(q, r, data: nil, image_config: nil)
    super(q, r, -q - r, data: data, image_config: image_config)
  end

  def to_cube
    CubeHex.new(q, r, s, data: data, image_config: image_config)
  end
end
```

**Changes:**
- One object per hex instead of two — less GC pressure
- `axial_hex.is_a?(CubeHex)` → `true` (was also true via delegator, now explicit)
- `Grid#add` type check simplifies: `hex.is_a?(Rhex::CubeHex)` covers both classes
- `to_cube` creates a copy (semantically correct — previously returned the same object via `__getobj__`)

---

## Section 2: `Grid` Encapsulation + Thread Safety

### 2a. Internal interface instead of `instance_variable_get`

**Current:** `BfsPath`, `DfsPath`, `Reachable`, `FieldOfView` all bypass `Grid`'s public interface:

```ruby
grid_hash = grid.instance_variable_get(:@hash)
```

**Design:** Add a protected accessor on `Grid`:

```ruby
# grid.rb
protected

def grid_hash = @hash
```

Algorithm classes access it via `grid.send(:grid_hash)`. This is a deliberate internal contract — the algorithms are implementation details of `Grid` itself.

### 2b. Thread safety via `Mutex`

**Design:** Protect mutations with a `Mutex`; algorithms work on a snapshot:

```ruby
def initialize(...)
  @mutex = Mutex.new
  @hash = {}
  ...
end

def add(hex)
  @mutex.synchronize { @hash[key(hex)] = hex }
  self
end

def merge(other)
  @mutex.synchronize { ... }
  self
end

# Algorithm methods take a snapshot under the mutex:
def bfs_path(source, target, obstacles: [])
  snapshot = @mutex.synchronize { @hash.dup }
  BfsPath.new(snapshot, ...).call(source, target)
end
```

**What this guarantees:**
- `add` and `merge` are atomic
- Each algorithm call receives a consistent snapshot of the grid topology
- Cost: one O(n) hash dup per algorithm call (negligible vs algorithm complexity)

**What is NOT protected:** concurrent mutation of individual hex objects (`data=`, `image_config=`) — this is outside `Grid`'s responsibility. Document accordingly.

---

## Section 3: Memory Reductions

### 3a. `Reachable` — single tracking hash

**Current:** Two hashes with the same keys:

```ruby
visited = { start_packed_key => true }
distance_map = { start_packed_key => 0 }
```

**Design:** Remove `visited` entirely. Use `distance_map.key?` for the visited check:

```ruby
distance_map = { start_packed_key => 0 }

# instead of: next if visited.key?(neighbor_packed_key)
next if distance_map.key?(neighbor_packed_key)
```

**Savings:** ~50% memory for tracking structures. For 1000 hexes: eliminates ~1000 hash entries plus the `visited` hash object itself.

### 3b. `AutoCanvasMarkup` — bounding box without materializing vertices

**Current:** `vertices` creates 6 vertex pairs per hex to find 4 numbers (x_min, x_max, y_min, y_max). For 1000 hexes: 6000 arrays, 12000 Float objects.

**Design:** Compute bounds directly from hex centers ± half-span:

```ruby
def bounding_box
  @bounding_box ||= begin
    x_min = Float::INFINITY; x_max = -Float::INFINITY
    y_min = Float::INFINITY; y_max = -Float::INFINITY

    grid.each do |hex|
      hx = hex.coordinates.x
      hy = hex.coordinates.y
      hw = hex.width / 2.0
      hh = hex.height / 2.0

      x_min = hx - hw if hx - hw < x_min
      x_max = hx + hw if hx + hw > x_max
      y_min = hy - hh if hy - hh < y_min
      y_max = hy + hh if hy + hh > y_max
    end

    { x_min: x_min, x_max: x_max, y_min: y_min, y_max: y_max }
  end
end
```

Single pass, 4 floats tracked — no intermediate arrays.

---

## Section 4: Validation Performance

**Current:** `Draw::Hexagon#initialize` calls `Dry::Validation::Contract.new.call(default_image_config)` on every instantiation. For a 500-hex grid render: 500 contract executions on the same constant.

**Design:** Cache the validated default at class load time:

```ruby
class Hexagon
  VALIDATED_DEFAULT_IMAGE_CONFIG = begin
    result = Rhex::Contracts::ImageConfigContract.new.call(DEFAULT_IMAGE_CONFIG)
    raise ArgumentError, result.errors.to_h if result.failure?
    result.to_h.freeze
  end

  def initialize(gc:, hex:, default_image_config: VALIDATED_DEFAULT_IMAGE_CONFIG)
    @gc = gc
    @hex = hex
    @default_image_config = default_image_config
    # custom config is still validated if provided via keyword arg
  end
end
```

If a custom `default_image_config` is provided, validation runs normally (it's a non-default value). Only the default constant bypasses per-call validation.

**Additional:** Move `DEG_TO_RAD = Math::PI / 180.0` (currently duplicated in both `AutoCanvasMarkup` and `Draw::Hexagon`) into `Rhex::Constants`.

---

## Section 5: Duplication Elimination

### 5a. `BaseOrientedHex` — shared decorator base

`FlatToppedHex` and `PointyToppedHex` share: `Coordinates` struct, `initialize`, `size` attr, `coordinates` memoization, `radius` formula.

**Design:** Extract `Rhex::Decorators::BaseOrientedHex`:

```ruby
# decorators/base_oriented_hex.rb
class BaseOrientedHex < SimpleDelegator
  Coordinates = Struct.new(:x, :y, keyword_init: true)

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

  def coordinate_x = raise(NotImplementedError, "#{self.class}#coordinate_x")
  def coordinate_y = raise(NotImplementedError, "#{self.class}#coordinate_y")
end
```

Subclasses define only `ANGLES`, `height`, `width`, `coordinate_x`, `coordinate_y`.

### 5b. Remove `Object.const_get` string indirection

**Current:**
```ruby
FLAT_TOPPED_HEX_CLASS_NAME = "Rhex::Decorators::FlatToppedHex"
def hex_decorator_class = Object.const_get(FLAT_TOPPED_HEX_CLASS_NAME)
```

**Design:** Reference constants directly:
```ruby
def hex_decorator_class = Rhex::Decorators::FlatToppedHex
```

### 5c. Remove YAML→JSON→Hash round-trip in `ImageConfigs`

**Current:**
```ruby
JSON.parse(YAML.safe_load(File.read(file_path)).to_json).with_indifferent_access
```

**Design:**
```ruby
YAML.safe_load(File.read(file_path), symbolize_names: true)
```

**Consequence:** Remove `activesupport` from `gemspec` dependencies (verify no other usage first).

---

## Section 6: A\* Pathfinding with Binary Min-Heap

**Motivation:** BFS finds the shortest path but explores all equidistant nodes. A\* uses a heuristic (hex distance to target) to prioritize promising directions — fewer nodes explored on large grids.

**Heuristic:** `hex_distance(current, target)` — admissible and consistent for uniform-cost hex grids.

**MinHeap** — pure Ruby binary min-heap as a private nested class in `AstarPath`. No external gems.

```ruby
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
```

**A\* with lazy deletion** (avoids `decrease_key` complexity):

```ruby
class AstarPath
  def call(source, target)
    open_list = MinHeap.new
    open_list.push(0, [0, start_packed_key, start_hex])
    g_scores = { start_packed_key => 0 }
    parents = {}

    until open_list.empty?
      _, (g, current_packed_key, current) = open_list.pop

      next if g_scores.fetch(current_packed_key, Float::INFINITY) < g  # stale

      return reconstruct(parents, ...) if current_packed_key == target_packed_key

      each_neighbor(current) do |nq, nr, n_key, n_hex|
        new_g = g + 1
        next if g_scores.key?(n_key) && g_scores[n_key] <= new_g

        g_scores[n_key] = new_g
        parents[n_key] = current_packed_key
        f = new_g + ga.hex_distance(nq, nr, target_q, target_r)
        open_list.push(f, [new_g, n_key, n_hex])
      end
    end

    raise Grid::PathNotFoundError
  end
end
```

**Public interface:** `grid.astar_path(source, target, obstacles: [])` — identical to `bfs_path`.

**Complexity:** O(E log V) push/pop vs O(E·V) for naive min_by approach.

---

## Files Changed

| File | Change |
|------|--------|
| `lib/rhex/axial_hex.rb` | `< CubeHex` instead of `< SimpleDelegator` |
| `lib/rhex/grid.rb` | Add `Mutex`, `grid_hash` protected, pass snapshot to algorithms |
| `lib/rhex/bfs_path.rb` | Accept `grid_hash` directly, remove `grid` attr |
| `lib/rhex/dfs_path.rb` | Same as BfsPath |
| `lib/rhex/reachable.rb` | Same as BfsPath; merge `visited` into `distance_map` |
| `lib/rhex/field_of_view.rb` | Accept `grid_hash` directly |
| `lib/rhex/astar_path.rb` | **New file** — A\* with MinHeap |
| `lib/rhex/constants.rb` | Add `DEG_TO_RAD` |
| `lib/rhex/draw/hexagon.rb` | Cache validated default config |
| `lib/rhex/canvas_markups/auto_canvas_markup.rb` | Bounding box without vertices |
| `lib/rhex/decorators/base_oriented_hex.rb` | **New file** — shared base |
| `lib/rhex/decorators/flat_topped_hex.rb` | Inherit `BaseOrientedHex` |
| `lib/rhex/decorators/pointy_topped_hex.rb` | Inherit `BaseOrientedHex` |
| `lib/rhex/flat_topped_grid.rb` | Direct class reference |
| `lib/rhex/pointy_topped_grid.rb` | Direct class reference |
| `lib/rhex/image_configs.rb` | `YAML.safe_load(symbolize_names: true)` |
| `rhex.gemspec` | Remove `activesupport` (verify first) |
| `lib/rhex.rb` | Autoload `AstarPath`, `BaseOrientedHex` |
| Specs | Update for all changes; add AstarPath spec |

---

## Trade-offs and Non-Goals

- `AxialHex` keeps its public name and initializer signature unchanged
- `DfsPath` remains as-is algorithmically (DFS is intentional for exploration)
- No A\* heuristic tuning — uniform cost (weight 1) per edge is correct for standard hex grids
- `concurrent-ruby` is NOT added — `Mutex` from stdlib is sufficient
- Shadow-casting for `FieldOfView` is NOT included — O(n) improvement would require a significant rewrite and is deferred
