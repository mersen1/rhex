#include <math.h>
#include <stdint.h>
#include <stdlib.h>

#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

static const int32_t DIRECTIONS[6][2] = {
    {1, 0},
    {1, -1},
    {0, -1},
    {-1, 0},
    {-1, 1},
    {0, 1}};

static int32_t abs_int32(int32_t value) {
  return value < 0 ? -value : value;
}

static int cube_distance(int32_t q1, int32_t r1, int32_t q2, int32_t r2);

typedef struct {
  int32_t *qs;
  int32_t *rs;
  int32_t *values;
  int32_t capacity;
} Lookup;

static int32_t hash_qr(int32_t q, int32_t r) {
  /* Simple mixing; collisions resolved via linear probing */
  return (q * 73856093) ^ (r * 19349663);
}

static int32_t next_power_of_two(int32_t n) {
  int32_t cap = 1;
  while (cap < n) {
    cap <<= 1;
  }
  return cap;
}

static int lookup_init(Lookup *table, int32_t expected_size) {
  int32_t capacity = next_power_of_two(expected_size * 2 + 1);
  table->qs = calloc((size_t)capacity, sizeof(int32_t));
  table->rs = calloc((size_t)capacity, sizeof(int32_t));
  table->values = malloc((size_t)capacity * sizeof(int32_t));
  table->capacity = capacity;

  if (!table->qs || !table->rs || !table->values) {
    free(table->qs);
    free(table->rs);
    free(table->values);
    table->qs = NULL;
    table->rs = NULL;
    table->values = NULL;
    table->capacity = 0;
    return 0;
  }

  for (int32_t i = 0; i < capacity; i++) {
    table->values[i] = -1;
  }

  return 1;
}

static void lookup_free(Lookup *table) {
  free(table->qs);
  free(table->rs);
  free(table->values);
  table->qs = NULL;
  table->rs = NULL;
  table->values = NULL;
  table->capacity = 0;
}

static int lookup_insert(Lookup *table, int32_t q, int32_t r, int32_t value) {
  int32_t mask = table->capacity - 1;
  int32_t idx = hash_qr(q, r) & mask;

  for (size_t i = 0; i < (size_t)table->capacity; i++) {
    int32_t pos = (idx + i) & mask;
    int32_t existing_value = table->values[pos];

    if (existing_value == -1 || (table->qs[pos] == q && table->rs[pos] == r)) {
      table->qs[pos] = q;
      table->rs[pos] = r;
      table->values[pos] = value;
      return 1;
    }
  }

  return 0; /* Table full */
}

static int lookup_get(const Lookup *table, int32_t q, int32_t r) {
  if (!table || table->capacity <= 0) {
    return -1;
  }

  int32_t mask = table->capacity - 1;
  int32_t idx = hash_qr(q, r) & mask;

  for (size_t i = 0; i < (size_t)table->capacity; i++) {
    int32_t pos = (idx + i) & mask;
    int32_t existing_value = table->values[pos];

    if (existing_value == -1) {
      return -1;
    }
    if (table->qs[pos] == q && table->rs[pos] == r) {
      return existing_value;
    }
  }

  return -1;
}

typedef struct {
  int32_t index;
  int32_t distance;
  int32_t neg_r;
  int32_t q;
} NeighborEntry;

static int neighbor_entry_cmp(const NeighborEntry *a, const NeighborEntry *b) {
  if (a->distance != b->distance) {
    return (a->distance < b->distance) ? -1 : 1;
  }
  if (a->neg_r != b->neg_r) {
    return (a->neg_r < b->neg_r) ? -1 : 1;
  }
  if (a->q != b->q) {
    return (a->q < b->q) ? -1 : 1;
  }
  return 0;
}

static int collect_neighbors_sorted(int32_t current_index,
                                    const int32_t *grid_qs,
                                    const int32_t *grid_rs,
                                    const Lookup *grid_lookup,
                                    const Lookup *obstacles_lookup,
                                    const uint8_t *visited,
                                    int32_t target_q,
                                    int32_t target_r,
                                    int32_t *out_indices) {
  NeighborEntry entries[6];
  int count = 0;

  int32_t current_q = grid_qs[current_index];
  int32_t current_r = grid_rs[current_index];

  for (int dir = 0; dir < 6; dir++) {
    int32_t neighbor_q = current_q + DIRECTIONS[dir][0];
    int32_t neighbor_r = current_r + DIRECTIONS[dir][1];

    int neighbor_index = lookup_get(grid_lookup, neighbor_q, neighbor_r);
    if (neighbor_index < 0) {
      continue;
    }
    if (visited && visited[neighbor_index]) {
      continue;
    }
    if (lookup_get(obstacles_lookup, neighbor_q, neighbor_r) >= 0) {
      continue;
    }

    entries[count].index = neighbor_index;
    entries[count].distance = cube_distance(neighbor_q, neighbor_r, target_q, target_r);
    entries[count].neg_r = -neighbor_r;
    entries[count].q = neighbor_q;
    count++;
  }

  /* insertion sort for tiny array */
  for (int i = 1; i < count; i++) {
    NeighborEntry key = entries[i];
    int j = i - 1;
    while (j >= 0 && neighbor_entry_cmp(&key, &entries[j]) < 0) {
      entries[j + 1] = entries[j];
      j--;
    }
    entries[j + 1] = key;
  }

  for (int i = 0; i < count; i++) {
    out_indices[i] = entries[i].index;
  }

  return count;
}

typedef struct {
  int32_t index;
  int neighbor_count;
  int next_neighbor;
  int neighbors[6];
} DfsFrame;

static int32_t dfs_path_search(const int32_t *const grid_qs, const int32_t *const grid_rs, int32_t grid_len,
                               int32_t start_index, int32_t target_index,
                               const Lookup *grid_lookup, const Lookup *obstacles_lookup,
                               int32_t *out_qs, int32_t *out_rs, int32_t out_capacity) {
  if (start_index == target_index) {
    out_qs[0] = grid_qs[start_index];
    out_rs[0] = grid_rs[start_index];
    return 1;
  }

  DfsFrame *stack = malloc((size_t)grid_len * sizeof(DfsFrame));
  int32_t *path_indices = malloc((size_t)grid_len * sizeof(int32_t));
  int32_t *best_path = malloc((size_t)grid_len * sizeof(int32_t));
  int32_t *visited_depth = malloc((size_t)grid_len * sizeof(int32_t));

  if (!stack || !path_indices || !best_path || !visited_depth) {
    free(stack);
    free(path_indices);
    free(best_path);
    free(visited_depth);
    return -1;
  }

  for (int32_t i = 0; i < grid_len; i++) {
    visited_depth[i] = 0;
  }

  int32_t best_length = grid_len + 1;
  int stack_size = 0;
  int32_t path_len = 0;

  DfsFrame start_frame;
  start_frame.index = start_index;
  start_frame.neighbor_count = collect_neighbors_sorted(
      start_index, grid_qs, grid_rs, grid_lookup, obstacles_lookup, NULL, grid_qs[target_index], grid_rs[target_index], start_frame.neighbors);
  start_frame.next_neighbor = 0;

  stack[stack_size++] = start_frame;
  path_indices[path_len++] = start_index;
  visited_depth[start_index] = 1;

  while (stack_size > 0) {
    DfsFrame *frame = &stack[stack_size - 1];
    int32_t current_index = frame->index;

    if (current_index == target_index) {
      if (path_len < best_length) {
        best_length = path_len;
        for (int32_t i = 0; i < path_len && i < grid_len; i++) {
          best_path[i] = path_indices[i];
        }
      }
      stack_size--;
      path_len--;
      continue;
    }

    if (frame->next_neighbor >= frame->neighbor_count) {
      stack_size--;
      path_len--;
      continue;
    }

    /* Reverse iteration to mirror Ruby DFS push-on-stack order (last pushed, first popped) */
    int neighbor_pos = frame->neighbor_count - 1 - frame->next_neighbor;
    frame->next_neighbor++;

    int32_t neighbor_index = frame->neighbors[neighbor_pos];
    int32_t next_length = path_len + 1;

    if (next_length >= best_length) {
      continue;
    }

    if (visited_depth[neighbor_index] > 0 && visited_depth[neighbor_index] <= next_length) {
      continue;
    }

    visited_depth[neighbor_index] = next_length;

    DfsFrame next_frame;
    next_frame.index = neighbor_index;
    next_frame.neighbor_count = collect_neighbors_sorted(
        neighbor_index, grid_qs, grid_rs, grid_lookup, obstacles_lookup, NULL, grid_qs[target_index], grid_rs[target_index], next_frame.neighbors);
    next_frame.next_neighbor = 0;

    stack[stack_size++] = next_frame;
    path_indices[path_len++] = neighbor_index;
  }

  if (best_length == grid_len + 1) {
    free(stack);
    free(path_indices);
    free(best_path);
    free(visited_depth);
    return 0;
  }

  if (best_length > out_capacity) {
    free(stack);
    free(path_indices);
    free(best_path);
    free(visited_depth);
    return -1;
  }

  for (int32_t i = 0; i < best_length; i++) {
    int32_t idx = best_path[i];
    out_qs[i] = grid_qs[idx];
    out_rs[i] = grid_rs[idx];
  }

  free(stack);
  free(path_indices);
  free(best_path);
  free(visited_depth);

  return best_length;
}

static int32_t shortest_path(const int32_t *const grid_qs, const int32_t *const grid_rs, int32_t grid_len,
                             int32_t start_q, int32_t start_r, int32_t target_q, int32_t target_r,
                             const int32_t *obs_qs, const int32_t *obs_rs, int32_t obstacles_len,
                             int32_t *out_qs, int32_t *out_rs, int32_t out_capacity) {
  if (grid_len <= 0 || out_capacity < grid_len) {
    return -1;
  }

  Lookup grid_lookup = {0};
  if (!lookup_init(&grid_lookup, grid_len)) {
    return -1;
  }
  for (int32_t i = 0; i < grid_len; i++) {
    if (!lookup_insert(&grid_lookup, grid_qs[i], grid_rs[i], i)) {
      lookup_free(&grid_lookup);
      return -1;
    }
  }

  int32_t start_index = lookup_get(&grid_lookup, start_q, start_r);
  int32_t target_index = lookup_get(&grid_lookup, target_q, target_r);
  if (start_index < 0 || target_index < 0) {
    lookup_free(&grid_lookup);
    return -1;
  }

  if (start_index == target_index) {
    out_qs[0] = start_q;
    out_rs[0] = start_r;
    lookup_free(&grid_lookup);
    return 1;
  }

  Lookup obstacles_lookup = {0};
  if (obstacles_len > 0) {
    if (!lookup_init(&obstacles_lookup, obstacles_len)) {
      lookup_free(&grid_lookup);
      return -1;
    }
    for (int32_t i = 0; i < obstacles_len; i++) {
      if (!lookup_insert(&obstacles_lookup, obs_qs[i], obs_rs[i], i)) {
        lookup_free(&grid_lookup);
        lookup_free(&obstacles_lookup);
        return -1;
      }
    }
  }

  uint8_t *visited = calloc((size_t)grid_len, sizeof(uint8_t));
  int32_t *previous = malloc((size_t)grid_len * sizeof(int32_t));
  int32_t *queue = malloc((size_t)grid_len * sizeof(int32_t));

  if (!visited || !previous || !queue) {
    free(visited);
    free(previous);
    free(queue);
    lookup_free(&grid_lookup);
    lookup_free(&obstacles_lookup);
    return -1;
  }

  for (int32_t i = 0; i < grid_len; i++) {
    previous[i] = -1;
  }

  int32_t front = 0;
  int32_t back = 0;
  queue[back++] = start_index;
  visited[start_index] = 1;

  int found = 0;

  while (front < back && !found) {
    int32_t current_index = queue[front++];

    int32_t neighbor_indices[6];
    int neighbor_count = collect_neighbors_sorted(
        current_index, grid_qs, grid_rs, &grid_lookup, &obstacles_lookup, visited, target_q, target_r, neighbor_indices);

    for (int i = 0; i < neighbor_count; i++) {
      int32_t neighbor_index = neighbor_indices[i];
      if (visited[neighbor_index]) {
        continue;
      }

      visited[neighbor_index] = 1;
      previous[neighbor_index] = current_index;

      if (neighbor_index == target_index) {
        found = 1;
        break;
      }

      queue[back++] = neighbor_index;
    }
  }

  if (!found || previous[target_index] < 0) {
    free(visited);
    free(previous);
    free(queue);
    lookup_free(&grid_lookup);
    lookup_free(&obstacles_lookup);
    return 0;
  }

  int32_t path_length = 1;
  int32_t cursor = target_index;
  while (cursor != start_index) {
    cursor = previous[cursor];
    if (cursor < 0) {
      break;
    }
    path_length++;
  }

  if (path_length > out_capacity) {
    free(visited);
    free(previous);
    free(queue);
    lookup_free(&grid_lookup);
    lookup_free(&obstacles_lookup);
    return -1;
  }

  cursor = target_index;
  for (int32_t i = path_length - 1; i >= 0; i--) {
    out_qs[i] = grid_qs[cursor];
    out_rs[i] = grid_rs[cursor];
    cursor = previous[cursor];
    if (cursor < 0 && i != 0) {
      break;
    }
  }

  free(visited);
  free(previous);
  free(queue);
  lookup_free(&grid_lookup);
  lookup_free(&obstacles_lookup);

  return path_length;
}

static int cube_distance(int32_t q1, int32_t r1, int32_t q2, int32_t r2) {
  int32_t s1 = -q1 - r1;
  int32_t s2 = -q2 - r2;
  int32_t dq = abs_int32(q1 - q2);
  int32_t dr = abs_int32(r1 - r2);
  int32_t ds = abs_int32(s1 - s2);
  int32_t max1 = dq > dr ? dq : dr;
  return max1 > ds ? max1 : ds;
}

static void cube_round(double fq, double fr, double fs, int32_t *rq, int32_t *rr, int32_t *rs) {
  int32_t q = (int32_t)llround(fq);
  int32_t r = (int32_t)llround(fr);
  int32_t s = (int32_t)llround(fs);

  double q_diff = fabs((double)q - fq);
  double r_diff = fabs((double)r - fr);
  double s_diff = fabs((double)s - fs);

  if (q_diff > r_diff && q_diff > s_diff) {
    q = -r - s;
  } else if (r_diff > s_diff) {
    r = -q - s;
  } else {
    s = -q - r;
  }

  *rq = q;
  *rr = r;
  *rs = s;
}

static int line_blocked(int32_t start_q, int32_t start_r, int32_t target_q, int32_t target_r,
                        const Lookup *obstacles_lookup) {
  int distance = cube_distance(start_q, start_r, target_q, target_r);
  if (distance <= 0) {
    return 0;
  }

  const double offset_q = 1e-6;
  const double offset_r = 2e-6;
  const double offset_s = -3e-6;

  int32_t start_s = -start_q - start_r;
  int32_t target_s = -target_q - target_r;

  for (int step = 0; step <= distance; step++) {
    double t = (double)step / (double)distance;
    double qf = ((double)start_q * (1.0 - t)) + ((double)target_q * t) + offset_q;
    double rf = ((double)start_r * (1.0 - t)) + ((double)target_r * t) + offset_r;
    double sf = ((double)start_s * (1.0 - t)) + ((double)target_s * t) + offset_s;

    int32_t rq, rr, rs_unused;
    cube_round(qf, rf, sf, &rq, &rr, &rs_unused);

    if (lookup_get(obstacles_lookup, rq, rr) >= 0) {
      return 1;
    }
  }

  return 0;
}

EXPORT int32_t reachable(const int32_t *const grid_qs, const int32_t *const grid_rs, int32_t grid_len,
                         int32_t start_q, int32_t start_r, int32_t movements_limit,
                         const int32_t *obs_qs, const int32_t *obs_rs, int32_t obstacles_len,
                         int32_t *out_qs, int32_t *out_rs, int32_t out_capacity) {
  if (grid_len <= 0 || out_capacity < grid_len) {
    return 0;
  }

  Lookup grid_lookup = {0};
  if (!lookup_init(&grid_lookup, grid_len)) {
    return 0;
  }
  for (int32_t i = 0; i < grid_len; i++) {
    if (!lookup_insert(&grid_lookup, grid_qs[i], grid_rs[i], i)) {
      lookup_free(&grid_lookup);
      return 0;
    }
  }

  int start_index = lookup_get(&grid_lookup, start_q, start_r);
  if (start_index < 0) {
    lookup_free(&grid_lookup);
    return 0;
  }

  if (movements_limit <= 0) {
    out_qs[0] = start_q;
    out_rs[0] = start_r;
    lookup_free(&grid_lookup);
    return 1;
  }

  Lookup obstacles_lookup = {0};
  if (obstacles_len > 0) {
    if (!lookup_init(&obstacles_lookup, obstacles_len)) {
      lookup_free(&grid_lookup);
      return 0;
    }
    for (int32_t i = 0; i < obstacles_len; i++) {
      if (!lookup_insert(&obstacles_lookup, obs_qs[i], obs_rs[i], i)) {
        lookup_free(&grid_lookup);
        lookup_free(&obstacles_lookup);
        return 0;
      }
    }
  }

  uint8_t *visited = calloc((size_t)grid_len, sizeof(uint8_t));
  int32_t *distance = malloc((size_t)grid_len * sizeof(int32_t));
  int32_t *queue = malloc((size_t)grid_len * sizeof(int32_t));
  int32_t *order = malloc((size_t)grid_len * sizeof(int32_t));

  if (!visited || !distance || !queue || !order) {
    free(visited);
    free(distance);
    free(queue);
    free(order);
    lookup_free(&grid_lookup);
    lookup_free(&obstacles_lookup);
    return 0;
  }

  for (int32_t i = 0; i < grid_len; i++) {
    distance[i] = -1;
  }

  int32_t front = 0;
  int32_t back = 0;
  int32_t order_count = 0;

  queue[back++] = start_index;
  visited[start_index] = 1;
  distance[start_index] = 0;
  order[order_count++] = start_index;

  while (front < back) {
    int32_t current_index = queue[front++];
    int32_t current_q = grid_qs[current_index];
    int32_t current_r = grid_rs[current_index];
    int32_t current_distance = distance[current_index];

    if (current_distance >= movements_limit) {
      continue;
    }

    for (int dir = 0; dir < 6; dir++) {
      int32_t neighbor_q = current_q + DIRECTIONS[dir][0];
      int32_t neighbor_r = current_r + DIRECTIONS[dir][1];

      int neighbor_index = lookup_get(&grid_lookup, neighbor_q, neighbor_r);
      if (neighbor_index < 0) {
        continue;
      }
      if (visited[neighbor_index]) {
        continue;
      }
      if (lookup_get(&obstacles_lookup, neighbor_q, neighbor_r) >= 0) {
        continue;
      }

      visited[neighbor_index] = 1;
      distance[neighbor_index] = current_distance + 1;
      queue[back++] = neighbor_index;
      order[order_count++] = neighbor_index;
    }
  }

  for (int32_t i = 0; i < order_count; i++) {
    int32_t idx = order[i];
    out_qs[i] = grid_qs[idx];
    out_rs[i] = grid_rs[idx];
  }

  free(visited);
  free(distance);
  free(queue);
  free(order);
  lookup_free(&grid_lookup);
  lookup_free(&obstacles_lookup);

  return order_count;
}

EXPORT int32_t field_of_view(const int32_t *const grid_qs, const int32_t *const grid_rs, int32_t grid_len,
                             int32_t start_q, int32_t start_r,
                             const int32_t *obs_qs, const int32_t *obs_rs, int32_t obstacles_len,
                             int32_t *out_qs, int32_t *out_rs, int32_t out_capacity) {
  if (grid_len <= 1 || out_capacity < grid_len) {
    return 0;
  }

  Lookup grid_lookup = {0};
  if (!lookup_init(&grid_lookup, grid_len)) {
    return 0;
  }
  for (int32_t i = 0; i < grid_len; i++) {
    if (!lookup_insert(&grid_lookup, grid_qs[i], grid_rs[i], i)) {
      lookup_free(&grid_lookup);
      return 0;
    }
  }

  int start_index = lookup_get(&grid_lookup, start_q, start_r);
  if (start_index < 0) {
    lookup_free(&grid_lookup);
    return 0;
  }

  int32_t count = 0;

  Lookup obstacles_lookup = {0};
  if (obstacles_len > 0) {
    if (!lookup_init(&obstacles_lookup, obstacles_len)) {
      lookup_free(&grid_lookup);
      return 0;
    }
    for (int32_t i = 0; i < obstacles_len; i++) {
      if (!lookup_insert(&obstacles_lookup, obs_qs[i], obs_rs[i], i)) {
        lookup_free(&grid_lookup);
        lookup_free(&obstacles_lookup);
        return 0;
      }
    }
  }

  if (obstacles_len <= 0) {
    for (int32_t i = 0; i < grid_len; i++) {
      if (i == start_index) {
        continue;
      }
      out_qs[count] = grid_qs[i];
      out_rs[count] = grid_rs[i];
      count++;
    }
    lookup_free(&grid_lookup);
    lookup_free(&obstacles_lookup);
    return count;
  }

  int32_t start_qv = grid_qs[start_index];
  int32_t start_rv = grid_rs[start_index];

  for (int32_t i = 0; i < grid_len; i++) {
    if (i == start_index) {
      continue;
    }

    int blocked = line_blocked(start_qv, start_rv, grid_qs[i], grid_rs[i], &obstacles_lookup);
    if (blocked) {
      continue;
    }

    out_qs[count] = grid_qs[i];
    out_rs[count] = grid_rs[i];
    count++;
  }

  lookup_free(&grid_lookup);
  lookup_free(&obstacles_lookup);

  return count;
}

EXPORT int32_t bfs_path(const int32_t *const grid_qs, const int32_t *const grid_rs, int32_t grid_len,
                        int32_t start_q, int32_t start_r, int32_t target_q, int32_t target_r,
                        const int32_t *obs_qs, const int32_t *obs_rs, int32_t obstacles_len,
                        int32_t *out_qs, int32_t *out_rs, int32_t out_capacity) {
  return shortest_path(
      grid_qs, grid_rs, grid_len, start_q, start_r, target_q, target_r, obs_qs, obs_rs, obstacles_len, out_qs, out_rs, out_capacity);
}

EXPORT int32_t dfs_path(const int32_t *const grid_qs, const int32_t *const grid_rs, int32_t grid_len,
                        int32_t start_q, int32_t start_r, int32_t target_q, int32_t target_r,
                        const int32_t *obs_qs, const int32_t *obs_rs, int32_t obstacles_len,
                        int32_t *out_qs, int32_t *out_rs, int32_t out_capacity) {
  if (grid_len <= 0 || out_capacity < grid_len) {
    return -1;
  }

  Lookup grid_lookup = {0};
  if (!lookup_init(&grid_lookup, grid_len)) {
    return -1;
  }
  for (int32_t i = 0; i < grid_len; i++) {
    if (!lookup_insert(&grid_lookup, grid_qs[i], grid_rs[i], i)) {
      lookup_free(&grid_lookup);
      return -1;
    }
  }

  int32_t start_index = lookup_get(&grid_lookup, start_q, start_r);
  int32_t target_index = lookup_get(&grid_lookup, target_q, target_r);
  if (start_index < 0 || target_index < 0) {
    lookup_free(&grid_lookup);
    return -1;
  }

  Lookup obstacles_lookup = {0};
  if (obstacles_len > 0) {
    if (!lookup_init(&obstacles_lookup, obstacles_len)) {
      lookup_free(&grid_lookup);
      return -1;
    }
    for (int32_t i = 0; i < obstacles_len; i++) {
      if (!lookup_insert(&obstacles_lookup, obs_qs[i], obs_rs[i], i)) {
        lookup_free(&grid_lookup);
        lookup_free(&obstacles_lookup);
        return -1;
      }
    }
  }

  int32_t result = dfs_path_search(
      grid_qs, grid_rs, grid_len, start_index, target_index, &grid_lookup, &obstacles_lookup, out_qs, out_rs, out_capacity);

  lookup_free(&grid_lookup);
  lookup_free(&obstacles_lookup);

  return result;
}
