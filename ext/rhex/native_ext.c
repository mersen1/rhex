#include "ruby.h"

#include <math.h>
#include <stdint.h>
#include <stdlib.h>

/* Keep packed keys within Ruby's immediate Integer range on 64-bit builds. */
#define COORD_LIMIT (INT64_C(1) << 29)

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
        int64_t packed = rq * INT64_C(4294967296) +
                         (int64_t)((uint64_t)rr & UINT64_C(0xffffffff));
        if (RTEST(rb_hash_aref(obstacles, LL2NUM(packed)))) return Qtrue;
    }

    return Qfalse;
}

void
Init_native_ext(void)
{
    VALUE rhex = rb_define_module("Rhex");
    VALUE native = rb_define_module_under(rhex, "Native");
    rb_define_singleton_method(native, "line_blocked?", line_blocked, 5);
}
