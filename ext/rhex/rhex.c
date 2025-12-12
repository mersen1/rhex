#include "rhex.h"

VALUE rb_mRhex;
VALUE rb_cGrid;

void Init_rhex(void) {
  rb_mRhex = rb_define_module("Rhex");
  rb_cGrid = rb_define_class_under(rb_mRhex, "Grid", rb_cObject);

  init_grid_reachable();
  rb_define_method(rb_cGrid, "reachable", grid_reachable, -1);
}
