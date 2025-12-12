#include "rhex.h"

static ID id_q;
static ID id_r;
static ID id_obstacles;
static VALUE rb_eSourceHexNotInGrid;
static ID ivar_q;
static ID ivar_r;

static const int DIRECTIONS[6][2] = {
    {1, 0}, {1, -1}, {0, -1}, {-1, 0}, {-1, 1}, {0, 1}
};

static VALUE coord_value(VALUE hex, ID ivar, ID method) {
  VALUE v = rb_ivar_get(hex, ivar);
  if (NIL_P(v)) {
    v = rb_funcall(hex, method, 0);
  }
  return v;
}

void init_grid_reachable(void) {
  id_q = rb_intern("q");
  id_r = rb_intern("r");
  id_obstacles = rb_intern("obstacles");
  ivar_q = rb_intern("@q");
  ivar_r = rb_intern("@r");
  rb_eSourceHexNotInGrid = rb_const_get(rb_cGrid, rb_intern("SourceHexNotInGrid"));
}

// Вспомогательная функция для создания ключа [q, r]
// static функции здесь ОК, так как они нужны только внутри этого файла
static VALUE coordinate_key(long q, long r) {
  VALUE ary = rb_ary_new_capa(2); // new_capa чуть быстрее new2
  rb_ary_push(ary, LONG2NUM(q));
  rb_ary_push(ary, LONG2NUM(r));
  return ary;
}

// Убираем static у функции grid_reachable, чтобы она была видна линковщику
VALUE grid_reachable(int argc, VALUE *argv, VALUE self) {
  /* Defaults */
  VALUE source = Qnil;
  VALUE movements_limit_val = INT2NUM(1);
  VALUE obstacles = Qnil;

  VALUE rest = Qnil;
  rb_scan_args(argc, argv, "11*", &source, &movements_limit_val, &rest);

  /* Если movements_limit передали как Hash с ключами, обрабатываем это как opts */
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

  VALUE grid_hash = rb_iv_get(self, "@hash");

  VALUE start_q = coord_value(source, ivar_q, id_q);
  VALUE start_r = coord_value(source, ivar_r, id_r);
  long start_q_long = NUM2LONG(start_q);
  long start_r_long = NUM2LONG(start_r);

  VALUE start_key = coordinate_key(start_q_long, start_r_long);
  
  if (NIL_P(rb_hash_aref(grid_hash, start_key))) {
    rb_raise(rb_eSourceHexNotInGrid, "Source hex not found in grid");
  }
  
  VALUE start_hex = rb_hash_aref(grid_hash, start_key);

  long movements_limit = NUM2LONG(movements_limit_val);
  if (movements_limit < 0) movements_limit = 0;

  obstacles = NIL_P(obstacles) ? rb_ary_new() : rb_Array(obstacles);

  VALUE obstacle_lookup = rb_hash_new();
  long obstacles_len = RARRAY_LEN(obstacles);
  for (long i = 0; i < obstacles_len; i++) {
    VALUE obstacle = RARRAY_AREF(obstacles, i);
    long oq = NUM2LONG(coord_value(obstacle, ivar_q, id_q));
    long or = NUM2LONG(coord_value(obstacle, ivar_r, id_r));
    rb_hash_aset(obstacle_lookup, coordinate_key(oq, or), Qtrue);
  }

  VALUE visited = rb_ary_new();
  VALUE visited_lookup = rb_hash_new();
  VALUE distance_lookup = rb_hash_new();
  VALUE queue = rb_ary_new();

  rb_hash_aset(visited_lookup, start_key, Qtrue);
  rb_hash_aset(distance_lookup, start_key, LONG2NUM(0));
  rb_ary_push(visited, start_hex);
  rb_ary_push(queue, start_hex);

  long front = 0;

  while (front < RARRAY_LEN(queue)) {
    VALUE current_hex = RARRAY_AREF(queue, front);
    front++;

    // ВАЖНО: rb_funcall медленный.
    // Если BFS тормозит, перепишите это на rb_ivar_get, если знаете имена переменных внутри Hex
    long current_q = NUM2LONG(coord_value(current_hex, ivar_q, id_q));
    long current_r = NUM2LONG(coord_value(current_hex, ivar_r, id_r));

    VALUE current_key = coordinate_key(current_q, current_r);
    long current_distance = NUM2LONG(rb_hash_aref(distance_lookup, current_key));

    if (current_distance >= movements_limit) {
      continue;
    }

    for (int dir = 0; dir < 6; dir++) {
      long neighbor_q = current_q + DIRECTIONS[dir][0];
      long neighbor_r = current_r + DIRECTIONS[dir][1];
      VALUE neighbor_key = coordinate_key(neighbor_q, neighbor_r);

      if (!NIL_P(rb_hash_aref(obstacle_lookup, neighbor_key))) {
        continue;
      }
      if (!NIL_P(rb_hash_aref(visited_lookup, neighbor_key))) {
        continue;
      }

      VALUE neighbor_hex = rb_hash_aref(grid_hash, neighbor_key);
      if (NIL_P(neighbor_hex)) {
        continue;
      }

      rb_hash_aset(visited_lookup, neighbor_key, Qtrue);
      rb_hash_aset(distance_lookup, neighbor_key, LONG2NUM(current_distance + 1));
      rb_ary_push(visited, neighbor_hex);
      rb_ary_push(queue, neighbor_hex);
    }
  }

  return visited;
}