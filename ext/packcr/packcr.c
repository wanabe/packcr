#include <ruby.h>

VALUE cPackcr_CodeBlock, cPackcr_Node, cPackcr_Stream, cPackcr_Buffer;

static void packcr_ptr_mark(void *ptr) {
}

static void packcr_ptr_free(void *ptr) {
    xfree(ptr);
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

struct packcr_context_data {
    context_t *ctx;
};

static void packcr_context_mark(void *ptr) {
    /* struct packcr_context_data *packcr_context = ptr; */
    /* TODO: add the mark logic */
}

static void packcr_context_struct_free(struct packcr_context_data *packcr_context) {
    if (packcr_context->ctx) {
        destroy_context(packcr_context->ctx);
        packcr_context->ctx = NULL;
    }
}

static void packcr_context_free(void *ptr) {
    struct packcr_context_data *packcr_context = ptr;

    packcr_context_struct_free(packcr_context);
    xfree(packcr_context);
}

static size_t packcr_context_memsize(const void *ptr) {
    return sizeof(struct packcr_context_data) + sizeof(context_t);
}

static const rb_data_type_t packcr_context_data_type = {
    "packcr_context",
    {packcr_context_mark, packcr_context_free, packcr_context_memsize,},
    0, 0, RUBY_TYPED_WB_PROTECTED | RUBY_TYPED_FREE_IMMEDIATELY
};

static VALUE packcr_context_s_alloc(VALUE klass) {
    struct packcr_context_data *packcr_context;
    VALUE obj = TypedData_Make_Struct(klass, struct packcr_context_data, &packcr_context_data_type, packcr_context);

    /* TODO: add the initialize logic for the C struct */

    return obj;
}

static VALUE packcr_context_initialize(VALUE self, VALUE arg) {
    struct packcr_context_data *packcr_context;
    VALUE path;

    TypedData_Get_Struct(self, struct packcr_context_data, &packcr_context_data_type, packcr_context);

    path = rb_check_string_type(arg);
    if (NIL_P(path)) {
        rb_raise(rb_eArgError, "bad path: %"PRIsVALUE, rb_inspect(arg));
    }

    rb_funcall(self, rb_intern("init"), 1, path);
    packcr_context->ctx = create_context(self);

    if (rb_block_given_p()) {
        rb_yield(self);
        packcr_context_struct_free(packcr_context);
    }
    return self;
}

static VALUE packcr_context_parse(VALUE self) {
    struct packcr_context_data *packcr_context;

    TypedData_Get_Struct(self, struct packcr_context_data, &packcr_context_data_type, packcr_context);

    if (!packcr_context->ctx) {
        rb_raise(rb_eRuntimeError, "closed context");
    }
    packcr_context->ctx->robj = self;
    return parse(packcr_context->ctx) ? Qtrue : Qfalse;
}

static VALUE packcr_context_generate(VALUE self, VALUE sstream) {
    struct packcr_context_data *packcr_context;

    TypedData_Get_Struct(self, struct packcr_context_data, &packcr_context_data_type, packcr_context);

    if (!packcr_context->ctx) {
        rb_raise(rb_eRuntimeError, "closed context");
    }
    packcr_context->ctx->robj = self;
    generate(packcr_context->ctx, sstream);
    return self;
}

static VALUE packcr_context_destroy(VALUE self) {
    struct packcr_context_data *packcr_context;

    TypedData_Get_Struct(self, struct packcr_context_data, &packcr_context_data_type, packcr_context);

    packcr_context_struct_free(packcr_context);
    return self;
}

static VALUE packcr_context_commit_buffer(VALUE self) {
    VALUE rbuffer;
    char_array_t *buffer;
    rbuffer = rb_ivar_get(self, rb_intern("@buffer"));
    TypedData_Get_Struct(rbuffer, char_array_t, &packcr_ptr_data_type, buffer);
    assert(NUM2SIZET(rb_funcall(rbuffer, rb_intern("len"), 0)) >= NUM2SIZET(rb_ivar_get(self, rb_intern("@bufcur"))));
    if (NUM2SIZET(rb_ivar_get(self, rb_intern("@linepos"))) < NUM2SIZET(rb_ivar_get(self, rb_intern("@bufpos"))) + NUM2SIZET(rb_ivar_get(self, rb_intern("@bufcur")))) {
        const bool ascii = RB_TEST(rb_ivar_get(self, rb_intern("@ascii")));
	size_t count = ascii ? NUM2SIZET(rb_ivar_get(self, rb_intern("@bufcur"))) : count_characters(buffer->buf, 0, NUM2SIZET(rb_ivar_get(self, rb_intern("@bufcur"))));
        rb_ivar_set(self, rb_intern("@charnum"), NUM2SIZET(rb_ivar_get(self, rb_intern("@charnum"))) + count);
    }
    memmove(buffer->buf, buffer->buf + NUM2SIZET(rb_ivar_get(self, rb_intern("@bufcur"))), NUM2SIZET(rb_funcall(rbuffer, rb_intern("len"), 0)) - NUM2SIZET(rb_ivar_get(self, rb_intern("@bufcur"))));
    buffer->len -= NUM2SIZET(rb_ivar_get(self, rb_intern("@bufcur")));
    rb_ivar_set(self, rb_intern("@bufpos"), SIZET2NUM(NUM2SIZET(rb_ivar_get(self, rb_intern("@bufpos"))) + NUM2SIZET(rb_ivar_get(self, rb_intern("@bufcur")))));
    rb_ivar_set(self, rb_intern("@bufcur"), SIZET2NUM(0));
    return self;
}

static VALUE packcr_context_refill_buffer(VALUE self, VALUE rnum) {
    size_t num = NUM2SIZET(rnum);
    VALUE rbuffer = rb_ivar_get(self, rb_intern("@buffer"));
    char_array_t *buffer;
    TypedData_Get_Struct(rbuffer, char_array_t, &packcr_ptr_data_type, buffer);
    if (NUM2SIZET(rb_funcall(rbuffer, rb_intern("len"), 0)) >= NUM2SIZET(rb_ivar_get(self, rb_intern("@bufcur"))) + num)
        return SIZET2NUM(NUM2SIZET(rb_funcall(rbuffer, rb_intern("len"), 0)) - NUM2SIZET(rb_ivar_get(self, rb_intern("@bufcur"))));
    while (NUM2SIZET(rb_funcall(rbuffer, rb_intern("len"), 0)) < NUM2SIZET(rb_ivar_get(self, rb_intern("@bufcur"))) + num) {
        const VALUE c = rb_funcall(rb_ivar_get(self, rb_intern("@ifile")), rb_intern("getc"), 0);
        if (c == Qnil) break;
        char_array__add(buffer, (char)RSTRING_PTR(c)[0]);
    }
    
    return SIZET2NUM(NUM2SIZET(rb_funcall(rbuffer, rb_intern("len"), 0)) - NUM2SIZET(rb_ivar_get(self, rb_intern("@bufcur"))));
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
    char_array_t *buffer;

    rbuffer = rb_ivar_get(rctx, rb_intern("@buffer"));
    TypedData_Get_Struct(rbuffer, char_array_t, &packcr_ptr_data_type, buffer);
    n = buffer->len;
    stream__write_text(self, buffer->buf, (n > 0 && buffer->buf[n - 1] == '\r') ? n - 1 : n);
    rb_ivar_set(rctx, rb_intern("@bufcur"), SIZET2NUM(n));
    return self;
}

static VALUE packcr_stream_write_line_directive(VALUE self, VALUE rfname, VALUE rlineno) {
    const char *fname = StringValuePtr(rfname);
    size_t lineno = NUM2SIZET(rlineno);
    stream__printf(self, "#line " FMT_LU " \"", (ulong_t)(lineno + 1));
    stream__write_escaped_string(self, fname, strlen(fname));
    stream__puts(self, "\"\n");
    return self;
}

void Init_packcr(void) {
    VALUE cPackcr, cPackcr_Context;

    cPackcr = rb_const_get(rb_cObject, rb_intern("Packcr"));

    cPackcr_Context = rb_define_class_under(cPackcr, "Context", rb_cObject);
    rb_define_alloc_func(cPackcr_Context, packcr_context_s_alloc);
    rb_define_method(cPackcr_Context, "initialize", packcr_context_initialize, 1);
    rb_define_method(cPackcr_Context, "parse", packcr_context_parse, 0);
    rb_define_method(cPackcr_Context, "_generate", packcr_context_generate, 1);
    rb_define_method(cPackcr_Context, "destroy", packcr_context_destroy, 0);
    rb_define_method(cPackcr_Context, "commit_buffer", packcr_context_commit_buffer, 0);
    rb_define_method(cPackcr_Context, "refill_buffer", packcr_context_refill_buffer, 1);

    cPackcr_CodeBlock = rb_define_class_under(cPackcr, "CodeBlock", rb_cObject);
    rb_define_alloc_func(cPackcr_CodeBlock, packcr_code_block_s_alloc);

    cPackcr_Node = rb_define_class_under(cPackcr, "Node", rb_cObject);
    rb_define_alloc_func(cPackcr_Node, packcr_node_s_alloc);

    cPackcr_Buffer = rb_define_class_under(cPackcr, "Buffer", rb_cObject);
    rb_define_alloc_func(cPackcr_Buffer, packcr_buffer_s_alloc);
    rb_define_method(cPackcr_Buffer, "max", packcr_buffer_max, 0);
    rb_define_method(cPackcr_Buffer, "len", packcr_buffer_len, 0);
    rb_define_method(cPackcr_Buffer, "[]", packcr_buffer_entry, 1);

    cPackcr_Stream = rb_const_get(cPackcr, rb_intern("Stream"));
    rb_define_method(cPackcr_Stream, "write_code_block", packcr_stream_write_code_block, 3);
    rb_define_method(cPackcr_Stream, "write_context_buffer", packcr_stream_write_context_buffer, 1);
    rb_define_method(cPackcr_Stream, "write_line_directive", packcr_stream_write_line_directive, 2);
}
