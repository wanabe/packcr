#include <ruby.h>

VALUE cPackcr_CodeBlock, cPackcr_Node, cPackcr_Stream;

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

static VALUE packcr_context_generate(VALUE self, VALUE sstream, VALUE hstream) {
    struct packcr_context_data *packcr_context;

    TypedData_Get_Struct(self, struct packcr_context_data, &packcr_context_data_type, packcr_context);

    if (!packcr_context->ctx) {
        rb_raise(rb_eRuntimeError, "closed context");
    }
    packcr_context->ctx->robj = self;
    generate(packcr_context->ctx, sstream, hstream);
    return self;
}

static VALUE packcr_context_destroy(VALUE self) {
    struct packcr_context_data *packcr_context;

    TypedData_Get_Struct(self, struct packcr_context_data, &packcr_context_data_type, packcr_context);

    packcr_context_struct_free(packcr_context);
    return self;
}

static VALUE packcr_stream_write_code_block(VALUE self, VALUE rcode, VALUE rindent, VALUE rfname) {
    size_t indent = NUM2SIZET(rindent);
    const char *fname = StringValuePtr(rfname);
    stream__write_code_block(self, rcode, indent, fname);
    return self;
}

void Init_packcr(void) {
    VALUE cPackcr, cPackcr_Context;

    cPackcr = rb_const_get(rb_cObject, rb_intern("Packcr"));

    cPackcr_Context = rb_define_class_under(cPackcr, "Context", rb_cObject);
    rb_define_alloc_func(cPackcr_Context, packcr_context_s_alloc);
    rb_define_method(cPackcr_Context, "initialize", packcr_context_initialize, 1);
    rb_define_method(cPackcr_Context, "parse", packcr_context_parse, 0);
    rb_define_method(cPackcr_Context, "_generate", packcr_context_generate, 2);
    rb_define_method(cPackcr_Context, "destroy", packcr_context_destroy, 0);

    cPackcr_CodeBlock = rb_define_class_under(cPackcr, "CodeBlock", rb_cObject);
    rb_define_alloc_func(cPackcr_CodeBlock, packcr_code_block_s_alloc);

    cPackcr_Node = rb_define_class_under(cPackcr, "Node", rb_cObject);
    rb_define_alloc_func(cPackcr_Node, packcr_node_s_alloc);

    cPackcr_Stream = rb_const_get(cPackcr, rb_intern("Stream"));
    rb_define_method(cPackcr_Stream, "write_code_block", packcr_stream_write_code_block, 3);
}
