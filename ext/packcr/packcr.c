#include <ruby.h>
#include <ruby/encoding.h>

VALUE cPackcr, cPackcr_CodeBlock, cPackcr_Node, cPackcr_Stream, cPackcr_Generator;

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

static VALUE packcr_code_block_s_alloc(VALUE klass) {
    code_block_t *code;
    VALUE obj = TypedData_Make_Struct(klass, code_block_t, &packcr_ptr_data_type, code);

    code->text = NULL;
    code->len = 0;
    code->line = VOID_VALUE;
    code->col = VOID_VALUE;

    return obj;
}

static VALUE packcr_code_block_text(VALUE self) {
    code_block_t *code;
    TypedData_Get_Struct(self, code_block_t, &packcr_ptr_data_type, code);

    return rb_str_new2(code->text);
}

static VALUE packcr_code_block_len(VALUE self) {
    code_block_t *code;
    TypedData_Get_Struct(self, code_block_t, &packcr_ptr_data_type, code);

    return SIZET2NUM(code->len);
}

static VALUE packcr_code_block_line(VALUE self) {
    code_block_t *code;
    TypedData_Get_Struct(self, code_block_t, &packcr_ptr_data_type, code);

    return SIZET2NUM(code->line);
}

static VALUE packcr_code_block_init(VALUE self, VALUE text, VALUE len, VALUE line, VALUE col) {
    code_block_t *code;
    char *ctext;
    TypedData_Get_Struct(self, code_block_t, &packcr_ptr_data_type, code);

    ctext = StringValuePtr(text);
    code->text = strndup_e(ctext, strlen(ctext));
    code->len = NUM2SIZET(len);
    code->line = NUM2SIZET(line);
    code->col = NUM2SIZET(col);

    return self;
}

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
    node_t *node;
    VALUE vars = rb_ary_new();
    node_const_array_t *v;
    size_t k;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_ACTION:
        v = &node->data.action.vars;
        break;
    case NODE_ERROR:
        v = &node->data.error.vars;
        break;
    case NODE_RULE:
        v = &node->data.rule.vars;
        break;
    default:
        return Qnil;
    }
    k = 0;
    while (k < v->len) {
        node_t *node = (node_t *)v->buf[k++];
        VALUE rvar = TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, node);
        rb_ary_push(vars, rvar);
    }
    return vars;
}

static VALUE packcr_node_set_vars(VALUE self, VALUE vars) {
    node_t *node;
    node_const_array_t *v;
    size_t i;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_ACTION:
        v = &node->data.action.vars;
        break;
    case NODE_ERROR:
        v = &node->data.error.vars;
        break;
    case NODE_RULE:
        v = &node->data.rule.vars;
        break;
    default:
        return Qnil;
    }
    if (NIL_P(vars)) {
        node_const_array__init(v);
        vars = rb_ary_new();
    } else {
        node_const_array__clear(v);
        for (i = 0; i < (size_t)RARRAY_LEN(vars); i++) {
            VALUE rnode = rb_ary_entry(vars, i);
            node_t *node;
            TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
            node_const_array__add(v, node);
        }
    }
    rb_ivar_set(self, rb_intern("@vars"), vars);
    return vars;
}

static VALUE packcr_node_add_var(VALUE self, VALUE rnode) {
    node_t *node;
    node_const_array_t *v;
    size_t i = 0;
    VALUE vars = rb_ary_new();
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_ACTION:
        v = &node->data.action.vars;
        break;
    case NODE_ERROR:
        v = &node->data.error.vars;
        break;
    case NODE_RULE:
        v = &node->data.rule.vars;
        break;
    default:
        return Qnil;
    }
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node_const_array__add(v, node);
    while (i < v->len) {
        node_t *node = (node_t *)v->buf[i++];
        VALUE rvar = TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, node);
        rb_ary_push(vars, rvar);
    }
    rb_ivar_set(self, rb_intern("@vars"), vars);
    return rnode;
}

static VALUE packcr_node_capts(VALUE self) {
    node_t *node;
    VALUE capts = rb_ary_new();
    node_const_array_t *v;
    size_t k;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_ACTION:
        v = &node->data.action.capts;
        break;
    case NODE_ERROR:
        v = &node->data.error.capts;
        break;
    case NODE_RULE:
        v = &node->data.rule.capts;
        break;
    default:
        return Qnil;
    }
    k = 0;
    while (k < v->len) {
        node_t *node = (node_t *)v->buf[k++];
        VALUE rnode = TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, node);
        rb_ary_push(capts, rnode);
    }
    rb_ivar_set(self, rb_intern("@capts"), capts);
    return capts;
}

static VALUE packcr_node_set_capts(VALUE self, VALUE capts) {
    node_t *node;
    node_const_array_t *v;
    size_t i;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_ACTION:
        v = &node->data.action.capts;
        break;
    case NODE_ERROR:
        v = &node->data.error.capts;
        break;
    case NODE_RULE:
        v = &node->data.rule.capts;
        break;
    default:
        return Qnil;
    }
    if (NIL_P(capts)) {
        node_const_array__init(v);
        capts = rb_ary_new();
    } else {
        node_const_array__clear(v);
        for (i = 0; i < (size_t)RARRAY_LEN(capts); i++) {
            VALUE rnode = rb_ary_entry(capts, i);
            node_t *node;
            TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
            node_const_array__add(v, node);
        }
    }
    rb_ivar_set(self, rb_intern("@capts"), capts);
    return capts;
}

static VALUE packcr_node_add_capt(VALUE self, VALUE rnode) {
    node_t *node;
    node_const_array_t *v;
    size_t i;
    VALUE capts;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_ACTION:
        v = &node->data.action.capts;
        break;
    case NODE_ERROR:
        v = &node->data.error.capts;
        break;
    case NODE_RULE:
        v = &node->data.rule.capts;
        break;
    default:
        return Qnil;
    }
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node_const_array__add(v, node);

    i = 0;
    capts = rb_ary_new();
    while (i < v->len) {
        node_t *node = (node_t *)v->buf[i++];
        VALUE rcapt = TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, node);
        rb_ary_push(capts, rcapt);
    }
    rb_ivar_set(self, rb_intern("@capts"), capts);
    return rnode;
}

static VALUE packcr_node_nodes(VALUE self) {
    node_t *node;
    VALUE nodes = rb_ary_new();
    node_array_t *a;
    size_t i = 0;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_SEQUENCE:
        a = &node->data.sequence.nodes;
        break;
    case NODE_ALTERNATE:
        a = &node->data.alternate.nodes;
        break;
    default:
        return Qnil;
    }
    while (i < a->len) {
        node_t *n = (node_t *)a->buf[i++];
        VALUE rn = TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, n);
        rb_ary_push(nodes, rn);
    }
    rb_ivar_set(self, rb_intern("@nodes"), nodes);
    return nodes;
}

static VALUE packcr_node_set_nodes(VALUE self, VALUE rnodes) {
    node_t *node;
    node_array_t *a;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_SEQUENCE:
        a = &node->data.sequence.nodes;
        break;
    case NODE_ALTERNATE:
        a = &node->data.alternate.nodes;
        break;
    default:
        return Qnil;
    }
    if (NIL_P(rnodes)) {
        node_array__init(a);
    }
    return rnodes;
}

static VALUE packcr_node_code(VALUE self) {
    node_t *node;
    code_block_t *code;
    VALUE rcode;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_ACTION:
        code = &node->data.action.code;
        break;
    case NODE_ERROR:
        code = &node->data.error.code;
        break;
    default:
        return Qnil;
    }
    rcode = TypedData_Wrap_Struct(cPackcr_CodeBlock, &packcr_ptr_data_type, code);
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
    node_t *node;
    node_t *expr;
    VALUE rexpr;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_RULE:
        expr = node->data.rule.expr;
        break;
    case NODE_QUANTITY:
        expr = node->data.quantity.expr;
        break;
    case NODE_PREDICATE:
        expr = node->data.predicate.expr;
        break;
    case NODE_CAPTURE:
        expr = node->data.capture.expr;
        break;
    case NODE_ERROR:
        expr = node->data.error.expr;
        break;
    default:
        return Qnil;
    }
    rexpr = TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, expr);
    rb_ivar_set(self, rb_intern("@expr"), rexpr);
    return rexpr;
}

static VALUE packcr_node_set_expr(VALUE self, VALUE rexpr) {
    node_t *node;
    node_t **e;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_RULE:
        e = &node->data.rule.expr;
        break;
    case NODE_QUANTITY:
        e = &node->data.quantity.expr;
        break;
    case NODE_PREDICATE:
        e = &node->data.predicate.expr;
        break;
    case NODE_CAPTURE:
        e = &node->data.capture.expr;
        break;
    case NODE_ERROR:
        e = &node->data.error.expr;
        break;
    default:
        return Qnil;
    }
    if (NIL_P(rexpr)) {
        *e = NULL;
    } else {
        rb_ivar_set(self, rb_intern("@expr"), rexpr);
        TypedData_Get_Struct(rexpr, node_t, &packcr_ptr_data_type, *e);
    }
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
    node_t *node;
    node_t *rule;
    VALUE rrule;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    switch (node->type) {
    case NODE_REFERENCE:
        rule = (node_t *)node->data.reference.rule;
        break;
    default:
        rule = NULL;
    }
    if (rule == NULL) {
        return Qnil;
    }
    rrule = TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, rule);
    rb_ivar_set(self, rb_intern("@rule"), rrule);
    return rrule;
}

static VALUE packcr_node_set_rule(VALUE self, VALUE rrule) {
    node_t *node;
    node_t *rule;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);
    TypedData_Get_Struct(rrule, node_t, &packcr_ptr_data_type, rule);

    switch (node->type) {
    case NODE_REFERENCE:
        node->data.reference.rule = rule;
        rb_ivar_set(self, rb_intern("@rule"), rrule);
        return rrule;
    default:
        return Qnil;
    }
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
    node_t *node, *cchild;
    node_array_t *a;
    VALUE rnodes;
    size_t i;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);
    TypedData_Get_Struct(child, node_t, &packcr_ptr_data_type, cchild);

    switch (node->type) {
    case NODE_SEQUENCE:
        a = &node->data.sequence.nodes;
        break;
    case NODE_ALTERNATE:
        a = &node->data.alternate.nodes;
        break;
    default:
        return Qnil;
    }
    node_array__add(a, cchild);

    i = 0;
    rnodes = rb_ary_new();
    while (i < a->len) {
        node_t *n = (node_t *)a->buf[i++];
        VALUE rn = TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, n);
        rb_ary_push(rnodes, rn);
    }
    rb_ivar_set(self, rb_intern("@nodes"), rnodes);
    return self;
}

static VALUE packcr_context_initialize(int argc, VALUE *argv, VALUE self) {
    VALUE path, arg, hash;

    rb_scan_args(argc, argv, "1:", &arg, &hash);
    path = rb_check_string_type(arg);
    if (NIL_P(path)) {
        rb_raise(rb_eArgError, "bad path: %"PRIsVALUE, rb_inspect(arg));
    }

    if (NIL_P(hash)) {
        rb_funcall(self, rb_intern("init"), 1, path);
    } else {
        VALUE  args[2];
        args[0] = path;
        args[1] = hash;
        rb_funcallv_kw(self, rb_intern("init"), 2, args, 1);
    }

    if (rb_block_given_p()) {
        rb_yield(self);
    }
    return self;
}

void Init_packcr(void) {
    VALUE cPackcr_Context;

    cPackcr = rb_const_get(rb_cObject, rb_intern("Packcr"));
    rb_const_set(rb_cObject, rb_intern("VOID_VALUE"), SIZET2NUM(VOID_VALUE));

    cPackcr_Context = rb_const_get(cPackcr, rb_intern("Context"));
    rb_define_method(cPackcr_Context, "initialize", packcr_context_initialize, -1);
    rb_define_method(cPackcr_Context, "parse_primary", parse_primary, 1);

    cPackcr_CodeBlock = rb_define_class_under(cPackcr, "CodeBlock", rb_cObject);
    rb_define_alloc_func(cPackcr_CodeBlock, packcr_code_block_s_alloc);
    rb_define_method(cPackcr_CodeBlock, "text", packcr_code_block_text, 0);
    rb_define_method(cPackcr_CodeBlock, "len", packcr_code_block_len, 0);
    rb_define_method(cPackcr_CodeBlock, "line", packcr_code_block_line, 0);
    rb_define_method(cPackcr_CodeBlock, "init", packcr_code_block_init, 4);

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

    cPackcr_Stream = rb_const_get(cPackcr, rb_intern("Stream"));

    cPackcr_Generator = rb_const_get(cPackcr, rb_intern("Generator"));
}
