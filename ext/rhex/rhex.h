#ifndef RHEX_H
#define RHEX_H

#include "ruby.h"

extern VALUE rb_mRhex;
extern VALUE rb_cGrid;

void init_grid_reachable(void);
VALUE grid_reachable(int argc, VALUE *argv, VALUE self);

#endif