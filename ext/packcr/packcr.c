#include <ruby.h>
#include <ruby/encoding.h>

VALUE cPackcr, cPackcr_Node;

#include "packcc/packcc.c"

void Init_packcr(void) {
    cPackcr = rb_const_get(rb_cObject, rb_intern("Packcr"));
}
