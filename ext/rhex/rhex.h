#ifndef RHEX_H
#define RHEX_H

#include "ruby.h"

extern VALUE rb_mRhex;
extern VALUE rb_cGrid;

void init_grid(void);
VALUE grid_reachable(int argc, VALUE *argv, VALUE self);
VALUE grid_field_of_view(int argc, VALUE *argv, VALUE self);
VALUE grid_bfs_path(int argc, VALUE *argv, VALUE self);
VALUE grid_dfs_path(int argc, VALUE *argv, VALUE self);

#endif