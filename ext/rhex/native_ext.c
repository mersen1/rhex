#include "ruby.h"

#include <math.h>
#include <stdint.h>
#include <stdlib.h>

/* Keep packed keys within Ruby's immediate Integer range on 64-bit builds. */
#define COORD_LIMIT (INT64_C(1) << 29)

static ID id_q, id_r;

static int
read_coord(VALUE value, int64_t *out)
{
    if (!RB_FIXNUM_P(value)) return 0;
    *out = NUM2LL(value);
    return *out > -COORD_LIMIT && *out < COORD_LIMIT;
}

static int
read_hex_coords(VALUE hex, int64_t *q, int64_t *r)
{
    return read_coord(rb_funcall(hex, id_q, 0), q) &&
           read_coord(rb_funcall(hex, id_r, 0), r);
}

static VALUE
packed_key(int64_t q, int64_t r)
{
    int64_t packed = q * INT64_C(4294967296) +
                     (int64_t)((uint64_t)r & UINT64_C(0xffffffff));
    return LL2NUM(packed);
}

static const int8_t neighbor_dq[6] = { 1, 1, 0, -1, -1, 0 };
static const int8_t neighbor_dr[6] = { 0, -1, -1, 0, 1, 1 };

typedef struct {
    VALUE key;
    VALUE hex;
    int64_t q, r, distance, cross;
} bfs_neighbor;

static int
neighbor_before(const bfs_neighbor *a, const bfs_neighbor *b)
{
    if (a->distance != b->distance) return a->distance < b->distance;
    if (a->cross != b->cross) return a->cross < b->cross;
    if (a->q != b->q) return a->q < b->q;
    return a->r < b->r;
}

/* Returns parents on success, Qfalse if unreachable, Qnil for Ruby fallback. */
static VALUE
bfs_parents(VALUE self, VALUE grid, VALUE obstacles, VALUE start_hex,
            VALUE start_key, VALUE source_q_value, VALUE source_r_value,
            VALUE target_q_value, VALUE target_r_value, VALUE target_key)
{
    int64_t source_q, source_r, target_q, target_r;
    int64_t line_delta_q, line_delta_r;
    VALUE parents, queue;
    long front = 0;

    (void)self;
    if (CLASS_OF(grid) != rb_cHash || CLASS_OF(obstacles) != rb_cHash ||
        !read_coord(source_q_value, &source_q) || !read_coord(source_r_value, &source_r) ||
        !read_coord(target_q_value, &target_q) || !read_coord(target_r_value, &target_r)) {
        return Qnil;
    }

    line_delta_q = target_q - source_q;
    line_delta_r = target_r - source_r;
    parents = rb_hash_new();
    queue = rb_ary_new();
    rb_hash_aset(parents, start_key, Qtrue);
    rb_ary_push(queue, start_hex);

    while (front < RARRAY_LEN(queue)) {
        VALUE current = RARRAY_AREF(queue, front++);
        VALUE current_key;
        int64_t cq, cr;
        bfs_neighbor neighbors[6];
        int count = 0;

        if ((front & 1023) == 0) rb_thread_check_ints();
        if (!read_hex_coords(current, &cq, &cr)) return Qnil;
        current_key = packed_key(cq, cr);

        for (int i = 0; i < 6; i++) {
            int64_t nq = cq + neighbor_dq[i];
            int64_t nr = cr + neighbor_dr[i];
            int64_t ds, dq, dr;
            VALUE key, hex;

            if (nq <= -COORD_LIMIT || nq >= COORD_LIMIT ||
                nr <= -COORD_LIMIT || nr >= COORD_LIMIT) return Qnil;

            key = packed_key(nq, nr);
            if (rb_hash_lookup2(obstacles, key, Qundef) != Qundef ||
                rb_hash_lookup2(parents, key, Qundef) != Qundef) continue;
            hex = rb_hash_aref(grid, key);
            if (!RTEST(hex)) continue;

            dq = nq - target_q;
            dr = nr - target_r;
            ds = (nq + nr) - (target_q + target_r);
            neighbors[count].distance = (llabs(dq) + llabs(dr) + llabs(ds)) / 2;
            neighbors[count].cross = llabs((line_delta_q * (source_r - nr)) -
                                           ((source_q - nq) * line_delta_r));
            neighbors[count].q = nq;
            neighbors[count].r = nr;
            neighbors[count].key = key;
            neighbors[count].hex = hex;
            count++;
        }

        /* At most six entries: insertion sort preserves Ruby's lexicographic tie-break. */
        for (int i = 1; i < count; i++) {
            bfs_neighbor item = neighbors[i];
            int j = i;
            while (j > 0 && neighbor_before(&item, &neighbors[j - 1])) {
                neighbors[j] = neighbors[j - 1];
                j--;
            }
            neighbors[j] = item;
        }

        for (int i = 0; i < count; i++) {
            VALUE key = neighbors[i].key;
            /* The six coordinates are distinct and were already filtered above. */
            rb_hash_aset(parents, key, current_key);
            /* Packed keys can be heap-allocated Integers on 32-bit Ruby. */
            if (key == target_key || (!RB_FIXNUM_P(key) && RTEST(rb_equal(key, target_key)))) return parents;
            rb_ary_push(queue, neighbors[i].hex);
        }
    }

    return Qfalse;
}

/* Uses the result array as the BFS queue and a single hash for visited keys. */
static VALUE
reachable(VALUE self, VALUE grid, VALUE obstacles, VALUE start_hex,
          VALUE start_key, VALUE limit_value)
{
    VALUE visited, result;
    long front = 0;
    int64_t depth = 0, limit;

    (void)self;
    if (CLASS_OF(grid) != rb_cHash || CLASS_OF(obstacles) != rb_cHash ||
        !RB_FIXNUM_P(limit_value)) return Qnil;
    /* A movement budget is not a coordinate; large budgets still visit each cell once. */
    limit = NUM2LL(limit_value);

    visited = rb_hash_new();
    result = rb_ary_new();
    rb_hash_aset(visited, start_key, Qtrue);
    rb_ary_push(result, start_hex);

    while (depth < limit && front < RARRAY_LEN(result)) {
        long layer_end = RARRAY_LEN(result);
        while (front < layer_end) {
            VALUE current = RARRAY_AREF(result, front++);
            int64_t cq, cr;

            if ((front & 1023) == 0) rb_thread_check_ints();
            if (!read_hex_coords(current, &cq, &cr)) return Qnil;

            for (int i = 0; i < 6; i++) {
                int64_t nq = cq + neighbor_dq[i];
                int64_t nr = cr + neighbor_dr[i];
                VALUE key, hex;

                if (nq <= -COORD_LIMIT || nq >= COORD_LIMIT ||
                    nr <= -COORD_LIMIT || nr >= COORD_LIMIT) return Qnil;

                key = packed_key(nq, nr);
                if (rb_hash_lookup2(obstacles, key, Qundef) != Qundef ||
                    rb_hash_lookup2(visited, key, Qundef) != Qundef) continue;
                hex = rb_hash_aref(grid, key);
                if (!RTEST(hex)) continue;

                rb_hash_aset(visited, key, Qtrue);
                rb_ary_push(result, hex);
            }
        }
        depth++;
    }

    return result;
}

static VALUE
line_blocked(VALUE self, VALUE source_q_value, VALUE source_r_value,
             VALUE target_q_value, VALUE target_r_value, VALUE obstacles)
{
    VALUE coordinates[] = { source_q_value, source_r_value, target_q_value, target_r_value };
    int64_t values[4];
    int64_t source_q, source_r, target_q, target_r, source_s, target_s;
    int64_t delta_q, delta_r, delta_s, distance, i;

    (void)self;

    /* Qnil asks the Ruby caller to use the unrestricted implementation. */
    if (CLASS_OF(obstacles) != rb_cHash) return Qnil;
    for (int j = 0; j < 4; j++) {
        if (!RB_FIXNUM_P(coordinates[j])) return Qnil;
        values[j] = NUM2LL(coordinates[j]);
        if (values[j] <= -COORD_LIMIT || values[j] >= COORD_LIMIT) return Qnil;
    }

    source_q = values[0];
    source_r = values[1];
    target_q = values[2];
    target_r = values[3];
    source_s = -source_q - source_r;
    target_s = -target_q - target_r;
    delta_q = target_q - source_q;
    delta_r = target_r - source_r;
    delta_s = target_s - source_s;
    distance = (llabs(delta_q) + llabs(delta_r) + llabs(delta_s)) / 2;

    for (i = 1; i <= distance; i++) {
        /* Hash access needs the GVL; periodically let Ruby handle signals and threads. */
        if ((i & 1023) == 0) rb_thread_check_ints();

        /* Preserve Ruby's i.to_f / distance and expression order at hex borders. */
        double t = (double)i / (double)distance;
        double fq = (double)source_q + ((double)delta_q * t) + 1e-6;
        double fr = (double)source_r + ((double)delta_r * t) + 2e-6;
        double fs = (double)source_s + ((double)delta_s * t) - 3e-6;
        int64_t rq = (int64_t)round(fq);
        int64_t rr = (int64_t)round(fr);
        int64_t rs = (int64_t)round(fs);
        double q_diff = fabs((double)rq - fq);
        double r_diff = fabs((double)rr - fr);
        double s_diff = fabs((double)rs - fs);

        if (q_diff > r_diff && q_diff > s_diff) {
            rq = -rr - rs;
        } else if (r_diff > s_diff) {
            rr = -rq - rs;
        }

        /* Ruby's (q << 32) | (r & 0xffffffff), without an allocated key. */
        if (RTEST(rb_hash_aref(obstacles, packed_key(rq, rr)))) return Qtrue;
    }

    return Qfalse;
}

void
Init_native_ext(void)
{
    VALUE rhex = rb_define_module("Rhex");
    VALUE native = rb_define_module_under(rhex, "Native");
    id_q = rb_intern("q");
    id_r = rb_intern("r");
    rb_define_singleton_method(native, "line_blocked?", line_blocked, 5);
    rb_define_singleton_method(native, "bfs_parents", bfs_parents, 9);
    rb_define_singleton_method(native, "reachable", reachable, 5);
}
