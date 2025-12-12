#include "rhex.h"

VALUE rb_mRhex;
VALUE rb_cGrid;

void Init_rhex(void) {
  rb_mRhex = rb_define_module("Rhex");
  rb_cGrid = rb_define_class_under(rb_mRhex, "Grid", rb_cObject);

  init_grid();
  rb_define_method(rb_cGrid, "reachable", grid_reachable, -1);
  rb_define_method(rb_cGrid, "field_of_view", grid_field_of_view, -1);
  rb_define_private_method(rb_cGrid, "bfs_path_native", grid_bfs_path, -1);
  rb_define_private_method(rb_cGrid, "dfs_path_native", grid_dfs_path, -1);
}
