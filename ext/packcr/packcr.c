#include <ruby.h>
#include <ruby/encoding.h>

VALUE cPackcr, cPackcr_Node;

static void packcr_ptr_mark(void *ptr) {
}

static void packcr_ptr_free(void *ptr) {
    /* TODO: temporary disable to avoid double free */
}

static size_t packcr_ptr_memsize(const void *ptr) {
    return 0;
}

static const rb_data_type_t packcr_ptr_data_type = {
    "packcr_ptr",
    {packcr_ptr_mark, packcr_ptr_free, packcr_ptr_memsize,},
    0, 0, RUBY_TYPED_WB_PROTECTED | RUBY_TYPED_FREE_IMMEDIATELY
};

#include "packcc/packcc.c"

static VALUE packcr_node_s_alloc(VALUE klass) {
    node_t *node;
    VALUE obj = TypedData_Make_Struct(klass, node_t, &packcr_ptr_data_type, node);

    return obj;
}

static VALUE packcr_node_name(VALUE self) {
    node_t *node;
    char *name;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_RULE:
        name = node->data.rule.name;
        break;
    case NODE_REFERENCE:
        name = node->data.reference.name;
        break;
    default:
        return Qnil;
    }
    return rb_str_new2(name);
}

static VALUE packcr_node_set_name(VALUE self, VALUE name) {
    node_t *node;
    char **n;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_RULE:
        n = &node->data.rule.name;
        break;
    case NODE_REFERENCE:
        n = &node->data.reference.name;
        break;
    default:
        return Qnil;
    }

    if (NIL_P(name)) {
        *n = NULL;
    } else {
        char *src = StringValuePtr(name);
        *n = strndup_e(src, strlen(src));
    }
    return name;
}

static VALUE packcr_node_index(VALUE self) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_ACTION:
        return SIZET2NUM(node->data.action.index);
        break;
    case NODE_ERROR:
        return SIZET2NUM(node->data.error.index);
        break;
    case NODE_CAPTURE:
        return SIZET2NUM(node->data.capture.index);
        break;
    case NODE_REFERENCE:
        return SIZET2NUM(node->data.reference.index);
        break;
    case NODE_EXPAND:
        return SIZET2NUM(node->data.expand.index);
        break;
    default:
        return Qnil;
    }
}

static VALUE packcr_node_set_index(VALUE self, VALUE index) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_ACTION:
        node->data.action.index = NUM2SIZET(index);
        break;
    case NODE_ERROR:
        node->data.error.index = NUM2SIZET(index);
        break;
    case NODE_CAPTURE:
        node->data.capture.index = NUM2SIZET(index);
        break;
    case NODE_REFERENCE:
        node->data.reference.index = NUM2SIZET(index);
        break;
    case NODE_EXPAND:
        node->data.expand.index = NUM2SIZET(index);
        break;
    default:
        return Qnil;
    }
    return index;
}

static VALUE packcr_node_vars(VALUE self) {
    return rb_ivar_get(self, rb_intern("@vars"));
}

static VALUE packcr_node_set_vars(VALUE self, VALUE vars) {
    if (NIL_P(vars)) {
        vars = rb_ary_new();
    }
    rb_ivar_set(self, rb_intern("@vars"), vars);
    return vars;
}

static VALUE packcr_node_add_var(VALUE self, VALUE rnode) {
    VALUE rvars = rb_ivar_get(self, rb_intern("@vars"));
    rb_ary_push(rvars, rnode);
    return rnode;
}

static VALUE packcr_node_capts(VALUE self) {
    return rb_ivar_get(self, rb_intern("@capts"));
}

static VALUE packcr_node_set_capts(VALUE self, VALUE capts) {
    if (NIL_P(capts)) {
        capts = rb_ary_new();
    }
    rb_ivar_set(self, rb_intern("@capts"), capts);
    return capts;
}

static VALUE packcr_node_add_capt(VALUE self, VALUE rnode) {
    VALUE rcapts = rb_ivar_get(self, rb_intern("@capts"));
    rb_ary_push(rcapts, rnode);
    return rnode;
}

static VALUE packcr_node_nodes(VALUE self) {
    return rb_ivar_get(self, rb_intern("@nodes"));
}

static VALUE packcr_node_set_nodes(VALUE self, VALUE rnodes) {
    if (NIL_P(rnodes)) {
        rnodes = rb_ary_new();
    }
    rb_ivar_set(self, rb_intern("@nodes"), rnodes);
    return rnodes;
}

static VALUE packcr_node_code(VALUE self) {
    return rb_ivar_get(self, rb_intern("@code"));
}

static VALUE packcr_node_set_code(VALUE self, VALUE rcode) {
    rb_ivar_set(self, rb_intern("@code"), rcode);
    return rcode;
}

static VALUE packcr_node_neg(VALUE self) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_PREDICATE:
        return node->data.predicate.neg ? Qtrue : Qfalse;
        break;
    default:
        return Qnil;
    }
}

static VALUE packcr_node_set_neg(VALUE self, VALUE neg) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_PREDICATE:
        node->data.predicate.neg = RB_TEST(neg) ? TRUE : FALSE;
        return neg;
        break;
    default:
        return Qnil;
    }
}

static VALUE packcr_node_ref(VALUE self) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_RULE:
        return INT2NUM(node->data.rule.ref);
    default:
        return Qnil;
    }
}

static VALUE packcr_node_set_ref(VALUE self, VALUE ref) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_RULE:
        node->data.rule.ref = NUM2INT(ref);
        return ref;
    default:
        return Qnil;
    }
}

static VALUE packcr_node_expr(VALUE self) {
    return rb_ivar_get(self, rb_intern("@expr"));
}

static VALUE packcr_node_set_expr(VALUE self, VALUE rexpr) {
    rb_ivar_set(self, rb_intern("@expr"), rexpr);
    return rexpr;
}

static VALUE packcr_node_var(VALUE self) {
    node_t *node;
    char *var;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_REFERENCE:
        var = node->data.reference.var;
        break;
    default:
        var = NULL;
    }
    if (var == NULL) {
        return Qnil;
    }
    return rb_str_new2(var);
}

static VALUE packcr_node_set_var(VALUE self, VALUE var) {
    node_t *node;
    char *cvar;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_REFERENCE:
        if (NIL_P(var)) {
            node->data.reference.var = NULL;
        } else {
            cvar = StringValuePtr(var);
            node->data.reference.var = strndup_e(cvar, strlen(cvar));
        }
        return var;
    default:
        return var;
    }
}

static VALUE packcr_node_rule(VALUE self) {
    return rb_ivar_get(self, rb_intern("@rule"));
}

static VALUE packcr_node_set_rule(VALUE self, VALUE rrule) {
    rb_ivar_set(self, rb_intern("@rule"), rrule);
    return rrule;
}

static VALUE packcr_node_value(VALUE self) {
    node_t *node;
    char *value;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_STRING:
        value = node->data.string.value;
        if (value != NULL) {
            return rb_str_new_cstr(value);
        }
        break;
    case NODE_CHARCLASS:
        value = node->data.charclass.value;
        if (value != NULL) {
            rb_encoding *enc = rb_utf8_encoding();
            return rb_enc_str_new_cstr(value, enc);
        }
        break;
    default:
        value = NULL;
    }
    return Qnil;
}

static VALUE packcr_node_set_value(VALUE self, VALUE value) {
    node_t *node;
    char **v;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_STRING:
        v = &node->data.string.value;
        break;
    case NODE_CHARCLASS:
        v = &node->data.charclass.value;
        break;
    default:
        return Qnil;
    }
    if (NIL_P(value)) {
        *v = NULL;
    } else {
        char *src = StringValuePtr(value);
        *v = strndup_e(src, strlen(src));
    }
    return value;
}

static VALUE packcr_node_min(VALUE self) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_QUANTITY:
        return INT2NUM(node->data.quantity.min);
    default:
        return Qnil;
    }
}

static VALUE packcr_node_set_min(VALUE self, VALUE rmin) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_QUANTITY:
        node->data.quantity.min = NUM2INT(rmin);
        return rmin;
    default:
        return Qnil;
    }
}

static VALUE packcr_node_max(VALUE self) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_QUANTITY:
        return INT2NUM(node->data.quantity.max);
    case NODE_SEQUENCE:
        return SIZET2NUM(node->data.sequence.nodes.max);
    case NODE_ALTERNATE:
        return SIZET2NUM(node->data.alternate.nodes.max);
    default:
        return Qnil;
    }
}

static VALUE packcr_node_set_max(VALUE self, VALUE rmax) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_QUANTITY:
        node->data.quantity.max = NUM2INT(rmax);
        return rmax;
    default:
        return Qnil;
    }
}

static VALUE packcr_node_type(VALUE self) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);
    return INT2NUM(node->type);
}

static VALUE packcr_node_set_type(VALUE self, VALUE rtype) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);
    node->type = NUM2INT(rtype);
    return rtype;
}

static VALUE packcr_node_line(VALUE self) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_RULE:
        return SIZET2NUM(node->data.rule.line);
    case NODE_REFERENCE:
        return SIZET2NUM(node->data.reference.line);
    case NODE_EXPAND:
        return SIZET2NUM(node->data.expand.line);
    default:
        return Qnil;
    }
}

static VALUE packcr_node_set_line(VALUE self, VALUE line) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_RULE:
        node->data.rule.line = NUM2SIZET(line);
        break;
    case NODE_REFERENCE:
        node->data.reference.line = NUM2SIZET(line);
        break;
    case NODE_EXPAND:
        node->data.expand.line = NUM2SIZET(line);
        break;
    default:
        return Qnil;
    }
    return line;
}

static VALUE packcr_node_col(VALUE self) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_RULE:
        return SIZET2NUM(node->data.rule.col);
    case NODE_REFERENCE:
        return SIZET2NUM(node->data.reference.col);
    case NODE_EXPAND:
        return SIZET2NUM(node->data.expand.col);
    default:
        return Qnil;
    }
}

static VALUE packcr_node_set_col(VALUE self, VALUE col) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_RULE:
        node->data.rule.col = NUM2SIZET(col);
        break;
    case NODE_REFERENCE:
        node->data.reference.col = NUM2SIZET(col);
        break;
    case NODE_EXPAND:
        node->data.expand.col = NUM2SIZET(col);
        break;
    default:
        return Qnil;
    }
    return col;
}

static VALUE packcr_node_add_ref(VALUE self) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    if (node->type == NODE_RULE) {
        node->data.rule.ref++;
    }
    return self;
}

static VALUE packcr_node_add_node(VALUE self, VALUE child) {
    VALUE rnodes = rb_ivar_get(self, rb_intern("@nodes"));
    rb_ary_push(rnodes, child);
    return self;
}

void Init_packcr(void) {
    cPackcr = rb_const_get(rb_cObject, rb_intern("Packcr"));
    rb_const_set(rb_cObject, rb_intern("VOID_VALUE"), SIZET2NUM(VOID_VALUE));

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

    rb_define_alloc_func(cPackcr_Node, packcr_node_s_alloc);
    rb_define_method(cPackcr_Node, "name", packcr_node_name, 0);
    rb_define_method(cPackcr_Node, "name=", packcr_node_set_name, 1);
    rb_define_method(cPackcr_Node, "expr", packcr_node_expr, 0);
    rb_define_method(cPackcr_Node, "expr=", packcr_node_set_expr, 1);
    rb_define_method(cPackcr_Node, "index", packcr_node_index, 0);
    rb_define_method(cPackcr_Node, "index=", packcr_node_set_index, 1);
    rb_define_method(cPackcr_Node, "vars", packcr_node_vars, 0);
    rb_define_method(cPackcr_Node, "vars=", packcr_node_set_vars, 1);
    rb_define_method(cPackcr_Node, "add_var", packcr_node_add_var, 1);
    rb_define_method(cPackcr_Node, "capts", packcr_node_capts, 0);
    rb_define_method(cPackcr_Node, "capts=", packcr_node_set_capts, 1);
    rb_define_method(cPackcr_Node, "add_capt", packcr_node_add_capt, 1);
    rb_define_method(cPackcr_Node, "nodes", packcr_node_nodes, 0);
    rb_define_method(cPackcr_Node, "nodes=", packcr_node_set_nodes, 1);
    rb_define_method(cPackcr_Node, "code", packcr_node_code, 0);
    rb_define_method(cPackcr_Node, "code=", packcr_node_set_code, 1);
    rb_define_method(cPackcr_Node, "neg", packcr_node_neg, 0);
    rb_define_method(cPackcr_Node, "neg=", packcr_node_set_neg, 1);
    rb_define_method(cPackcr_Node, "ref", packcr_node_ref, 0);
    rb_define_method(cPackcr_Node, "ref=", packcr_node_set_ref, 1);
    rb_define_method(cPackcr_Node, "var", packcr_node_var, 0);
    rb_define_method(cPackcr_Node, "var=", packcr_node_set_var, 1);
    rb_define_method(cPackcr_Node, "rule", packcr_node_rule, 0);
    rb_define_method(cPackcr_Node, "rule=", packcr_node_set_rule, 1);
    rb_define_method(cPackcr_Node, "value", packcr_node_value, 0);
    rb_define_method(cPackcr_Node, "value=", packcr_node_set_value, 1);
    rb_define_method(cPackcr_Node, "min", packcr_node_min, 0);
    rb_define_method(cPackcr_Node, "min=", packcr_node_set_min, 1);
    rb_define_method(cPackcr_Node, "max", packcr_node_max, 0);
    rb_define_method(cPackcr_Node, "max=", packcr_node_set_max, 1);
    rb_define_method(cPackcr_Node, "type", packcr_node_type, 0);
    rb_define_method(cPackcr_Node, "type=", packcr_node_set_type, 1);
    rb_define_method(cPackcr_Node, "line", packcr_node_line, 0);
    rb_define_method(cPackcr_Node, "line=", packcr_node_set_line, 1);
    rb_define_method(cPackcr_Node, "col", packcr_node_col, 0);
    rb_define_method(cPackcr_Node, "col=", packcr_node_set_col, 1);
    rb_define_method(cPackcr_Node, "add_ref", packcr_node_add_ref, 0);
    rb_define_method(cPackcr_Node, "add_node", packcr_node_add_node, 1);
}
