#include "rhex.h"
#include <math.h>
#include <stdint.h>
#include <stdlib.h>

// Global IDs for Ruby symbols
static ID id_q;
static ID id_r;
static ID id_obstacles;
static ID ivar_q;
static ID ivar_r;

// Exception classes
static VALUE rb_eGridDoesNotContainSourceError;
static VALUE rb_eGridDoesNotContainTargetError;
static VALUE rb_ePathNotFoundError;

// Hex neighbors directions
static const int DIRECTIONS[6][2] = {
    {1, 0},   // East
    {1, -1},  // North-East
    {0, -1},  // North-West
    {-1, 0},  // West
    {-1, 1},  // South-West
    {0, 1}    // South-East
};

// --- Helpers: Keys & Coords ---

static inline VALUE packed_key(long q, long r) {
    uint64_t uq = (uint64_t)q;
    uint64_t ur = (uint64_t)r;
    uint64_t combined = (uq << 32) | (ur & 0xFFFFFFFF);
    return ULL2NUM(combined);
}

static inline void unpack_key(VALUE pk, long *q, long *r) {
    uint64_t combined = NUM2ULL(pk);
    *q = (long)((int32_t)(combined >> 32));
    *r = (long)((int32_t)(combined & 0xFFFFFFFF));
}

static inline VALUE array_key(long q, long r) {
    VALUE ary = rb_ary_new_capa(2);
    rb_ary_push(ary, LONG2NUM(q));
    rb_ary_push(ary, LONG2NUM(r));
    return ary;
}

static inline long get_coord_fast(VALUE hex, ID ivar) {
    VALUE val = rb_ivar_get(hex, ivar);
    if (NIL_P(val)) {
         ID method = (ivar == ivar_q) ? id_q : id_r;
         val = rb_funcall(hex, method, 0);
    }
    return NUM2LONG(val);
}

static VALUE build_obstacle_lookup(VALUE obstacles) {
    VALUE obstacle_lookup = rb_hash_new();
    if (NIL_P(obstacles)) return obstacle_lookup;

    obstacles = rb_Array(obstacles);
    long len = RARRAY_LEN(obstacles);
    for (long i = 0; i < len; i++) {
        VALUE obs = RARRAY_AREF(obstacles, i);
        long oq = get_coord_fast(obs, ivar_q);
        long or = get_coord_fast(obs, ivar_r);
        rb_hash_aset(obstacle_lookup, packed_key(oq, or), Qtrue);
    }
    return obstacle_lookup;
}

static VALUE build_path_from_parents(VALUE grid_hash, VALUE parents, VALUE start_pk, VALUE target_pk) {
    VALUE path = rb_ary_new();
    VALUE current_pk = target_pk;

    long max_steps = RHASH_SIZE(parents) + 10;

    while (max_steps-- > 0) {
        long q, r;
        unpack_key(current_pk, &q, &r);

        VALUE hex = rb_hash_aref(grid_hash, array_key(q, r));

        if (NIL_P(hex)) rb_raise(rb_ePathNotFoundError, "Path corrupted during reconstruction");

        rb_ary_push(path, hex);

        if (current_pk == start_pk) break;

        VALUE parent_pk = rb_hash_aref(parents, current_pk);
        if (NIL_P(parent_pk)) rb_raise(rb_ePathNotFoundError, "Path broken during reconstruction");

        current_pk = parent_pk;
    }

    return rb_ary_reverse(path);
}

void init_grid(void) {
  id_q = rb_intern("q");
  id_r = rb_intern("r");
  id_obstacles = rb_intern("obstacles");
  ivar_q = rb_intern("@q");
  ivar_r = rb_intern("@r");

  rb_eGridDoesNotContainSourceError = rb_const_get(rb_cGrid, rb_intern("GridDoesNotContainSourceError"));
  rb_eGridDoesNotContainTargetError = rb_const_get(rb_cGrid, rb_intern("GridDoesNotContainTargetError"));
  rb_ePathNotFoundError = rb_const_get(rb_cGrid, rb_intern("PathNotFoundError"));
}

// --- Math Helpers ---

static long hex_distance(long q1, long r1, long q2, long r2) {
    return (labs(q1 - q2) + labs(q1 + r1 - q2 - r2) + labs(r1 - r2)) / 2;
}

static void hex_lerp(long q1, long r1, long q2, long r2, double t, long *out_q, long *out_r) {
    double s1 = -q1 - r1;
    double s2 = -q2 - r2;

    double fq = q1 + (q2 - q1) * t;
    double fr = r1 + (r2 - r1) * t;
    double fs = s1 + (s2 - s1) * t;

    fq += 1e-6; fr += 2e-6; fs += -3e-6;

    long rq = (long)round(fq);
    long rr = (long)round(fr);
    long rs = (long)round(fs);

    double q_diff = fabs(rq - fq);
    double r_diff = fabs(rr - fr);
    double s_diff = fabs(rs - fs);

    if (q_diff > r_diff && q_diff > s_diff) rq = -rr - rs;
    else if (r_diff > s_diff) rr = -rq - rs;

    *out_q = rq;
    *out_r = rr;
}

static int line_blocked(long start_q, long start_r, long target_q, long target_r, VALUE obstacle_lookup) {
    long dist = hex_distance(start_q, start_r, target_q, target_r);
    if (dist == 0) return 0;

    for (long i = 1; i <= dist; i++) {
        double t = (double)i / dist;
        long cq, cr;
        hex_lerp(start_q, start_r, target_q, target_r, t, &cq, &cr);

        if (!NIL_P(rb_hash_aref(obstacle_lookup, packed_key(cq, cr)))) return 1;
    }
    return 0;
}

// --- Algorithm: Reachable (BFS with Limit) ---

VALUE grid_reachable(int argc, VALUE *argv, VALUE self) {
  VALUE source = Qnil;
  VALUE movements_limit_val = INT2NUM(1);
  VALUE obstacles = Qnil;
  VALUE rest = Qnil;

  // Uses argc, argv
  rb_scan_args(argc, argv, "11*", &source, &movements_limit_val, &rest);

  if (RB_TYPE_P(movements_limit_val, T_HASH)) {
    VALUE obstacles_val = rb_hash_aref(movements_limit_val, ID2SYM(id_obstacles));
    if (!NIL_P(obstacles_val)) obstacles = obstacles_val;
    movements_limit_val = INT2NUM(1);
  } else if (!NIL_P(rest) && RARRAY_LEN(rest) > 0) {
    VALUE opts = RARRAY_AREF(rest, 0);
    if (RB_TYPE_P(opts, T_HASH)) {
      VALUE obstacles_val = rb_hash_aref(opts, ID2SYM(id_obstacles));
      if (!NIL_P(obstacles_val)) obstacles = obstacles_val;
    }
  }

  // Uses self
  VALUE grid_hash = rb_iv_get(self, "@hash");

  long start_q = get_coord_fast(source, ivar_q);
  long start_r = get_coord_fast(source, ivar_r);

  VALUE start_ary_key = array_key(start_q, start_r);

  if (NIL_P(rb_hash_aref(grid_hash, start_ary_key))) {
    rb_raise(rb_eGridDoesNotContainSourceError, "Source hex not found in grid");
  }
  VALUE start_hex = rb_hash_aref(grid_hash, start_ary_key);

  long movements_limit = NUM2LONG(movements_limit_val);
  if (movements_limit < 0) movements_limit = 0;

  VALUE obstacle_lookup = build_obstacle_lookup(obstacles);
  VALUE visited_list = rb_ary_new();
  VALUE visited_set = rb_hash_new();
  VALUE queue = rb_ary_new();
  VALUE distance_map = rb_hash_new();

  VALUE start_pk = packed_key(start_q, start_r);

  rb_hash_aset(visited_set, start_pk, Qtrue);
  rb_hash_aset(distance_map, start_pk, LONG2NUM(0));
  rb_ary_push(visited_list, start_hex);
  rb_ary_push(queue, start_hex);

  long front = 0;

  while (front < RARRAY_LEN(queue)) {
    VALUE current_hex = RARRAY_AREF(queue, front);
    front++;

    long current_q = get_coord_fast(current_hex, ivar_q);
    long current_r = get_coord_fast(current_hex, ivar_r);

    VALUE current_pk = packed_key(current_q, current_r);
    long current_dist = NUM2LONG(rb_hash_aref(distance_map, current_pk));

    if (current_dist >= movements_limit) continue;

    long next_dist_val = LONG2NUM(current_dist + 1);

    for (int dir = 0; dir < 6; dir++) {
      long n_q = current_q + DIRECTIONS[dir][0];
      long n_r = current_r + DIRECTIONS[dir][1];
      VALUE n_pk = packed_key(n_q, n_r);

      if (!NIL_P(rb_hash_aref(obstacle_lookup, n_pk))) continue;
      if (!NIL_P(rb_hash_aref(visited_set, n_pk))) continue;

      VALUE n_ary_key = array_key(n_q, n_r);
      VALUE n_hex = rb_hash_aref(grid_hash, n_ary_key);
      if (NIL_P(n_hex)) continue;

      rb_hash_aset(visited_set, n_pk, Qtrue);
      rb_hash_aset(distance_map, n_pk, next_dist_val);
      rb_ary_push(visited_list, n_hex);
      rb_ary_push(queue, n_hex);
    }
  }

  return visited_list;
}

// --- Algorithm: Field of View (FOV) ---

struct fov_data {
    long start_q;
    long start_r;
    VALUE start_hex;
    VALUE obstacle_lookup;
    VALUE visible_ary;
};

static int fov_iter_callback(VALUE key, VALUE target_hex, VALUE data_ptr) {
    (void)key;
    struct fov_data *data = (struct fov_data *)data_ptr;

    if (target_hex == data->start_hex) return ST_CONTINUE;

    long tq = get_coord_fast(target_hex, ivar_q);
    long tr = get_coord_fast(target_hex, ivar_r);

    if (!line_blocked(data->start_q, data->start_r, tq, tr, data->obstacle_lookup)) {
        rb_ary_push(data->visible_ary, target_hex);
    }
    return ST_CONTINUE;
}

VALUE grid_field_of_view(int argc, VALUE *argv, VALUE self) {
    VALUE source = Qnil;
    VALUE obstacles = Qnil;
    // Uses argc, argv
    rb_scan_args(argc, argv, "11", &source, &obstacles);

    // Uses self
    VALUE grid_hash = rb_iv_get(self, "@hash");

    long start_q = get_coord_fast(source, ivar_q);
    long start_r = get_coord_fast(source, ivar_r);

    VALUE start_ary_key = array_key(start_q, start_r);

    if (NIL_P(rb_hash_aref(grid_hash, start_ary_key))) {
        rb_raise(rb_eGridDoesNotContainSourceError, "Source not in grid");
    }
    VALUE start_hex = rb_hash_aref(grid_hash, start_ary_key);

    VALUE obstacle_lookup = build_obstacle_lookup(obstacles);

    struct fov_data data;
    data.start_q = start_q;
    data.start_r = start_r;
    data.start_hex = start_hex;
    data.obstacle_lookup = obstacle_lookup;
    data.visible_ary = rb_ary_new();

    // Uses fov_iter_callback
    rb_hash_foreach(grid_hash, fov_iter_callback, (VALUE)&data);

    return data.visible_ary;
}

// --- Algorithm: Pathfinding (BFS & DFS) ---

struct neighbor {
    long q;
    long r;
    long dist;     // heuristic: distance to target
    long cross_prod; // tie-breaker
    VALUE hex_obj; // cached object
};

// IMPROVED COMPARATOR: Deterministic & Straight
static int neighbor_cmp(const void *a, const void *b) {
    const struct neighbor *na = (const struct neighbor *)a;
    const struct neighbor *nb = (const struct neighbor *)b;

    if (na->dist != nb->dist) return (na->dist < nb->dist) ? -1 : 1;
    if (na->cross_prod != nb->cross_prod) return (na->cross_prod < nb->cross_prod) ? -1 : 1;
    if (na->q != nb->q) return (na->q < nb->q) ? -1 : 1;
    if (na->r != nb->r) return (na->r < nb->r) ? -1 : 1;

    return 0;
}

static long calc_cross_product(long start_q, long start_r, long target_q, long target_r, long n_q, long n_r) {
    long dx1 = target_q - start_q;
    long dy1 = target_r - start_r;
    long dx2 = start_q - n_q;
    long dy2 = start_r - n_r;
    return labs(dx1 * dy2 - dx2 * dy1);
}

// Generic solver. mode 0 = BFS (Queue), mode 1 = DFS (Stack)
static VALUE run_pathfinding(VALUE self, int argc, VALUE *argv, int mode) {
    VALUE source = Qnil, target = Qnil, kwargs = Qnil;
    rb_scan_args(argc, argv, "2:", &source, &target, &kwargs);

    VALUE obstacles = Qnil;
    if (!NIL_P(kwargs)) obstacles = rb_hash_aref(kwargs, ID2SYM(id_obstacles));

    VALUE grid_hash = rb_iv_get(self, "@hash");

    long start_q = get_coord_fast(source, ivar_q);
    long start_r = get_coord_fast(source, ivar_r);
    long target_q = get_coord_fast(target, ivar_q);
    long target_r = get_coord_fast(target, ivar_r);

    // --- Validation Checks ---

    VALUE start_ary_key = array_key(start_q, start_r);
    VALUE start_hex = rb_hash_aref(grid_hash, start_ary_key);
    if (NIL_P(start_hex)) {
        rb_raise(rb_eGridDoesNotContainSourceError, "Source hex not found in grid");
    }

    VALUE target_ary_key = array_key(target_q, target_r);
    if (NIL_P(rb_hash_aref(grid_hash, target_ary_key))) {
        rb_raise(rb_eGridDoesNotContainTargetError, "Target hex not found in grid");
    }

    if (start_q == target_q && start_r == target_r) {
        VALUE simple_path = rb_ary_new();
        rb_ary_push(simple_path, start_hex);
        return simple_path;
    }

    // --- Initialization ---

    VALUE obstacle_lookup = build_obstacle_lookup(obstacles);
    VALUE visited_set = rb_hash_new();
    VALUE parents = rb_hash_new();
    VALUE container = rb_ary_new();

    VALUE start_pk = packed_key(start_q, start_r);
    VALUE target_pk = packed_key(target_q, target_r);

    rb_hash_aset(visited_set, start_pk, Qtrue);
    rb_ary_push(container, start_hex);

    long front = 0;

    // --- Main Loop ---

    while (1) {
        long len = RARRAY_LEN(container);

        if (mode == 0) { // BFS
            if (front >= len) break;
        } else { // DFS
            if (len == 0) break;
        }

        VALUE current_hex;
        if (mode == 0) {
            current_hex = RARRAY_AREF(container, front);
            front++;
        } else {
            current_hex = rb_ary_pop(container);
        }

        long current_q = get_coord_fast(current_hex, ivar_q);
        long current_r = get_coord_fast(current_hex, ivar_r);
        VALUE current_pk = packed_key(current_q, current_r);

        struct neighbor neighs[6];
        int neigh_count = 0;

        for (int dir = 0; dir < 6; dir++) {
            long n_q = current_q + DIRECTIONS[dir][0];
            long n_r = current_r + DIRECTIONS[dir][1];
            VALUE n_pk = packed_key(n_q, n_r);

            if (!NIL_P(rb_hash_aref(obstacle_lookup, n_pk))) continue;
            if (!NIL_P(rb_hash_aref(visited_set, n_pk))) continue;

            VALUE n_hex = rb_hash_aref(grid_hash, array_key(n_q, n_r));
            if (NIL_P(n_hex)) continue;

            neighs[neigh_count].q = n_q;
            neighs[neigh_count].r = n_r;
            neighs[neigh_count].hex_obj = n_hex;

            if (mode == 0) {
                neighs[neigh_count].dist = hex_distance(n_q, n_r, target_q, target_r);
                neighs[neigh_count].cross_prod = calc_cross_product(start_q, start_r, target_q, target_r, n_q, n_r);
            }
            neigh_count++;
        }

        if (neigh_count > 1 && mode == 0) {
            qsort(neighs, neigh_count, sizeof(struct neighbor), neighbor_cmp);
        }

        for (int i = 0; i < neigh_count; i++) {
            VALUE n_pk = packed_key(neighs[i].q, neighs[i].r);

            if (!NIL_P(rb_hash_aref(visited_set, n_pk))) continue;

            rb_hash_aset(visited_set, n_pk, Qtrue);
            rb_hash_aset(parents, n_pk, current_pk);

            if (n_pk == target_pk) {
                return build_path_from_parents(grid_hash, parents, start_pk, n_pk);
            }

            rb_ary_push(container, neighs[i].hex_obj);
        }
    }

    rb_raise(rb_ePathNotFoundError, "Path not found");
    return Qnil;
}

VALUE grid_bfs_path(int argc, VALUE *argv, VALUE self) {
    return run_pathfinding(self, argc, argv, 0);
}

VALUE grid_dfs_path(int argc, VALUE *argv, VALUE self) {
    return run_pathfinding(self, argc, argv, 1);
}