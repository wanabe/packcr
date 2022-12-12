#include <ruby.h>
#include <ruby/encoding.h>

VALUE cPackcr, cPackcr_Node;

#include "packcc/packcc.c"

void Init_packcr(void) {
    cPackcr = rb_const_get(rb_cObject, rb_intern("Packcr"));

    cPackcr_Node = rb_define_class_under(cPackcr, "Node", rb_cObject);
    rb_const_set(cPackcr_Node, rb_intern("RULE"), INT2NUM(NODE_RULE));
    rb_const_set(cPackcr_Node, rb_intern("REFERENCE"), INT2NUM(NODE_REFERENCE));
    rb_const_set(cPackcr_Node, rb_intern("STRING"), INT2NUM(NODE_STRING));
    rb_const_set(cPackcr_Node, rb_intern("CHARCLASS"), INT2NUM(NODE_CHARCLASS));
    rb_const_set(cPackcr_Node, rb_intern("QUANTITY"), INT2NUM(NODE_QUANTITY));
    rb_const_set(cPackcr_Node, rb_intern("PREDICATE"), INT2NUM(NODE_PREDICATE));
    rb_const_set(cPackcr_Node, rb_intern("SEQUENCE"), INT2NUM(NODE_SEQUENCE));
    rb_const_set(cPackcr_Node, rb_intern("ALTERNATE"), INT2NUM(NODE_ALTERNATE));
    rb_const_set(cPackcr_Node, rb_intern("CAPTURE"), INT2NUM(NODE_CAPTURE));
    rb_const_set(cPackcr_Node, rb_intern("EXPAND"), INT2NUM(NODE_EXPAND));
    rb_const_set(cPackcr_Node, rb_intern("ACTION"), INT2NUM(NODE_ACTION));
    rb_const_set(cPackcr_Node, rb_intern("ERROR"), INT2NUM(NODE_ERROR));
}
