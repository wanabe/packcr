#include <ruby.h>
#include <ruby/encoding.h>

VALUE cPackcr, cPackcr_CodeBlock, cPackcr_Node, cPackcr_Stream, cPackcr_Buffer, cPackcr_Generator;

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

static VALUE packcr_node_s_alloc(VALUE klass) {
    node_t *node;
    VALUE obj = TypedData_Make_Struct(klass, node_t, &packcr_ptr_data_type, node);

    return obj;
}

static VALUE packcr_node_rule_name(VALUE self) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    return rb_str_new2(node->data.rule.name);
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
    return capts;
}

static VALUE packcr_node_nodes(VALUE self) {
    node_t *node;
    VALUE nodes = rb_ary_new();
    node_array_t *a;
    size_t k;
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
    k = 0;
    while (k < a->len) {
        node_t *n = (node_t *)a->buf[k++];
        VALUE rn = TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, n);
        rb_ary_push(nodes, rn);
    }
    return nodes;
}

static VALUE packcr_node_code(VALUE self) {
    node_t *node;
    code_block_t *code;
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
    return TypedData_Wrap_Struct(cPackcr_CodeBlock, &packcr_ptr_data_type, code);
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

static VALUE packcr_node_expr(VALUE self) {
    node_t *node;
    node_t *expr;
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
    return TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, expr);
}

static VALUE packcr_node_reference_var(VALUE self) {
    node_t *node;
    TypedData_Get_Struct(self, node_t, &packcr_ptr_data_type, node);

    return rb_str_new2(node->data.reference.var);
}

static VALUE packcr_buffer_s_alloc(VALUE klass) {
    char_array_t *buffer;
    VALUE obj = TypedData_Make_Struct(klass, char_array_t, &packcr_ptr_data_type, buffer);

    buffer->len = 0;
    buffer->max = 0;
    buffer->buf = NULL;

    return obj;
}

static VALUE packcr_buffer_max(VALUE self) {
    char_array_t *buffer;
    TypedData_Get_Struct(self, char_array_t, &packcr_ptr_data_type, buffer);
    return SIZET2NUM(buffer->max);
}

static VALUE packcr_buffer_len(VALUE self) {
    char_array_t *buffer;
    TypedData_Get_Struct(self, char_array_t, &packcr_ptr_data_type, buffer);
    return SIZET2NUM(buffer->len);
}

static VALUE packcr_buffer_entry(VALUE self, VALUE rindex) {
    char_array_t *buffer;
    TypedData_Get_Struct(self, char_array_t, &packcr_ptr_data_type, buffer);
    return INT2NUM(buffer->buf[NUM2SIZET(rindex)]);
}

static VALUE packcr_buffer_count_characters(VALUE self, VALUE rstart, VALUE rend) {
    size_t start = NUM2SIZET(rstart), end = NUM2SIZET(rend);
    /* UTF-8 multibyte character support but without checking UTF-8 validity */
    size_t n = 0, i = start;
    while (i < end) {
        const int c = (int)(unsigned char)NUM2SIZET(rb_funcall(self, rb_intern("[]"), 1, SIZET2NUM(i)));
        if (c == 0) break;
        n++;
        i += (c < 0x80) ? 1 : ((c & 0xe0) == 0xc0) ? 2 : ((c & 0xf0) == 0xe0) ? 3 : ((c & 0xf8) == 0xf0) ? 4 : /* invalid code */ 1;
    }
    return SIZET2NUM(n);
}

static VALUE packcr_buffer_add(VALUE self, VALUE rch) {
    char_array_t *buffer;
    char ch = (char)NUM2INT(rch);
    TypedData_Get_Struct(self, char_array_t, &packcr_ptr_data_type, buffer);
    if (buffer->max <= buffer->len) {
        const size_t n = buffer->len + 1;
        size_t m = buffer->max;
        if (m == 0) m = BUFFER_MIN_SIZE;
        while (m < n && m != 0) m <<= 1;
        if (m == 0) m = n; /* in case of shift overflow */
        buffer->buf = (char *)realloc_e(buffer->buf, m);
        buffer->max = m;
    }
    buffer->buf[buffer->len++] = ch;
    return self;
}

static VALUE packcr_buffer_to_s(VALUE self) {
    char_array_t *buffer;
    TypedData_Get_Struct(self, char_array_t, &packcr_ptr_data_type, buffer);
    return rb_str_new(buffer->buf, buffer->len);
}

static VALUE packcr_buffer_aset(VALUE self, VALUE pos, VALUE ch) {
    char_array_t *buffer;
    TypedData_Get_Struct(self, char_array_t, &packcr_ptr_data_type, buffer);
    buffer->buf[NUM2SIZET(pos)] = NUM2SIZET(ch);
    return ch;
}

static VALUE packcr_buffer_add_pos(VALUE self, VALUE offset) {
    char_array_t *buffer;
    TypedData_Get_Struct(self, char_array_t, &packcr_ptr_data_type, buffer);
    memmove(buffer->buf, buffer->buf + NUM2SIZET(offset), buffer->len - NUM2SIZET(offset));
    buffer->len -= NUM2SIZET(offset);
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

static VALUE packcr_context_parse(VALUE self) {
    return parse(self) ? Qtrue : Qfalse;
}

static VALUE packcr_stream_write_code_block(VALUE self, VALUE rcode, VALUE rindent, VALUE rfname) {
    size_t indent = NUM2SIZET(rindent);
    const char *fname = StringValuePtr(rfname);
    stream__write_code_block(self, rcode, indent, fname);
    return self;
}

static VALUE packcr_stream_write_context_buffer(VALUE self, VALUE rctx) {
    size_t n;
    VALUE rbuffer;
    VALUE text, last;

    rbuffer = rb_ivar_get(rctx, rb_intern("@buffer"));
    n = NUM2SIZET(rb_funcall(rbuffer, rb_intern("len"), 0));
    text = rb_funcall(rbuffer, rb_intern("to_s"), 0);
    last = rb_funcall(rb_funcall(text, rb_intern("[]"), 1, INT2NUM(-1)), rb_intern("ord"), 0);
    if (n > 0 && (char)NUM2SIZET(last) == '\r') {
        text = rb_funcall(text, rb_intern("[]="), 3, INT2NUM(-1), INT2NUM(1), rb_str_new2(""));
    }
    rb_funcall(self, rb_intern("write_text"), 1, text);
    rb_ivar_set(rctx, rb_intern("@bufcur"), SIZET2NUM(n));
    return self;
}

static VALUE packcr_generator_generate_code(VALUE gen, VALUE rnode, VALUE ronfail, VALUE rindent, VALUE rbare) {
    const node_t *node;
    int onfail = NUM2INT(ronfail);
    size_t indent = NUM2SIZET(rindent);
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    if (node == NULL) {
        print_error("Internal error [%d]\n", __LINE__);
        exit(-1);
    }
    switch (node->type) {
    case NODE_RULE:
        print_error("Internal error [%d]\n", __LINE__);
        exit(-1);
    case NODE_REFERENCE:
        if (node->data.reference.index != VOID_VALUE) {
            rb_funcall(rb_ivar_get(gen, rb_intern("@stream")), rb_intern("write_characters"), 2, SIZET2NUM(' '), SIZET2NUM(indent));
            stream__printf(rb_ivar_get(gen, rb_intern("@stream")), "if (!pcc_apply_rule(ctx, pcc_evaluate_rule_%s, &chunk->thunks, &(chunk->values.buf[" FMT_LU "]))) goto L%04d;\n",
                node->data.reference.name, (ulong_t)node->data.reference.index, onfail);
        }
        else {
            rb_funcall(rb_ivar_get(gen, rb_intern("@stream")), rb_intern("write_characters"), 2, SIZET2NUM(' '), SIZET2NUM(indent));
            stream__printf(rb_ivar_get(gen, rb_intern("@stream")), "if (!pcc_apply_rule(ctx, pcc_evaluate_rule_%s, &chunk->thunks, NULL)) goto L%04d;\n",
                node->data.reference.name, onfail);
        }
        return INT2NUM(CODE_REACH__BOTH);
    case NODE_STRING:
        return rb_funcall(gen, rb_intern("generate_matching_string_code"), 4, rb_str_new2(node->data.string.value), ronfail, rindent, rbare);
    case NODE_CHARCLASS:
        if (RB_TEST(rb_ivar_get(gen, rb_intern("@ascii")))) {
            VALUE charclass;
            if (node->data.charclass.value == NULL) {
                charclass = Qnil;
            } else {
                charclass = rb_str_new_cstr(node->data.charclass.value);
            }
            return rb_funcall(gen, rb_intern("generate_matching_charclass_code"), 4, charclass, ronfail, rindent, rbare);
        } else {
            VALUE charclass;
            if (node->data.charclass.value == NULL) {
                charclass = Qnil;
            } else {
                rb_encoding *enc = rb_utf8_encoding();
                charclass = rb_enc_str_new_cstr(node->data.charclass.value, enc);
            }
            return rb_funcall(gen, rb_intern("generate_matching_utf8_charclass_code"), 4, charclass, ronfail, rindent, rbare);
        }
    case NODE_QUANTITY:
        return rb_funcall(gen, rb_intern("generate_quantifying_code"), 6, rb_funcall(rnode, rb_intern("expr"), 0), INT2NUM(node->data.quantity.min), INT2NUM(node->data.quantity.max), ronfail, rindent, rbare);
    case NODE_PREDICATE:
        return rb_funcall(gen, rb_intern("generate_predicating_code"), 5, rb_funcall(rnode, rb_intern("expr"), 0), rb_funcall(rnode, rb_intern("neg"), 0), ronfail, rindent, rbare);
    case NODE_SEQUENCE:
        return rb_funcall(gen, rb_intern("generate_sequential_code"), 4, rb_funcall(rnode, rb_intern("nodes"), 0), ronfail, rindent, rbare);
    case NODE_ALTERNATE:
        return rb_funcall(gen, rb_intern("generate_alternative_code"), 4, rb_funcall(rnode, rb_intern("nodes"), 0), ronfail, rindent, rbare);
    case NODE_CAPTURE:
        return rb_funcall(
            gen, rb_intern("generate_capturing_code"), 5,
            rb_funcall(rnode, rb_intern("expr"), 0),
            SIZET2NUM(node->data.capture.index),
            ronfail, rindent, rbare
        );
    case NODE_EXPAND:
        return rb_funcall(gen, rb_intern("generate_expanding_code"), 4, rb_funcall(rnode, rb_intern("index"), 0), ronfail, rindent, rbare);
    case NODE_ACTION:
        return rb_funcall(
            gen, rb_intern("generate_thunking_action_code"), 7,
            SIZET2NUM(node->data.action.index),
            rb_funcall(rnode, rb_intern("vars"), 0),
            rb_funcall(rnode, rb_intern("capts"), 0),
            Qfalse,
            ronfail, rindent, rbare
        );
    case NODE_ERROR:
        return rb_funcall(
            gen, rb_intern("generate_thunking_error_code"), 7,
            rb_funcall(rnode, rb_intern("expr"), 0),
            SIZET2NUM(node->data.error.index),
            rb_funcall(rnode, rb_intern("vars"), 0),
            rb_funcall(rnode, rb_intern("capts"), 0),
            ronfail, rindent, rbare
        );
    default:
        print_error("Internal error [%d]\n", __LINE__);
        exit(-1);
    }
}

void Init_packcr(void) {
    VALUE cPackcr_Context;

    cPackcr = rb_const_get(rb_cObject, rb_intern("Packcr"));

    cPackcr_Context = rb_const_get(cPackcr, rb_intern("Context"));
    rb_define_method(cPackcr_Context, "initialize", packcr_context_initialize, -1);
    rb_define_method(cPackcr_Context, "parse", packcr_context_parse, 0);

    cPackcr_CodeBlock = rb_define_class_under(cPackcr, "CodeBlock", rb_cObject);
    rb_define_alloc_func(cPackcr_CodeBlock, packcr_code_block_s_alloc);

    cPackcr_Node = rb_define_class_under(cPackcr, "Node", rb_cObject);
    rb_define_alloc_func(cPackcr_Node, packcr_node_s_alloc);
    rb_define_method(cPackcr_Node, "rule_name", packcr_node_rule_name, 0);
    rb_define_method(cPackcr_Node, "expr", packcr_node_expr, 0);
    rb_define_method(cPackcr_Node, "index", packcr_node_index, 0);
    rb_define_method(cPackcr_Node, "vars", packcr_node_vars, 0);
    rb_define_method(cPackcr_Node, "capts", packcr_node_capts, 0);
    rb_define_method(cPackcr_Node, "nodes", packcr_node_nodes, 0);
    rb_define_method(cPackcr_Node, "code", packcr_node_code, 0);
    rb_define_method(cPackcr_Node, "neg", packcr_node_neg, 0);
    rb_define_method(cPackcr_Node, "reference_var", packcr_node_reference_var, 0);

    cPackcr_Buffer = rb_define_class_under(cPackcr, "Buffer", rb_cObject);
    rb_define_alloc_func(cPackcr_Buffer, packcr_buffer_s_alloc);
    rb_define_method(cPackcr_Buffer, "max", packcr_buffer_max, 0);
    rb_define_method(cPackcr_Buffer, "len", packcr_buffer_len, 0);
    rb_define_method(cPackcr_Buffer, "[]", packcr_buffer_entry, 1);
    rb_define_method(cPackcr_Buffer, "count_characters", packcr_buffer_count_characters, 2);
    rb_define_method(cPackcr_Buffer, "add", packcr_buffer_add, 1);
    rb_define_method(cPackcr_Buffer, "to_s", packcr_buffer_to_s, 0);
    rb_define_method(cPackcr_Buffer, "[]=", packcr_buffer_aset, 2);
    rb_define_method(cPackcr_Buffer, "add_pos", packcr_buffer_add_pos, 1);

    cPackcr_Stream = rb_const_get(cPackcr, rb_intern("Stream"));
    rb_define_method(cPackcr_Stream, "write_code_block", packcr_stream_write_code_block, 3);
    rb_define_method(cPackcr_Stream, "write_context_buffer", packcr_stream_write_context_buffer, 1);

    cPackcr_Generator = rb_const_get(cPackcr, rb_intern("Generator"));
    rb_define_method(cPackcr_Generator, "generate_code", packcr_generator_generate_code, 4);
}
