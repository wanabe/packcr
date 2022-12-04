#include <ruby.h>
#include "packcc/packcc.c"

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
    options_t opts;

    TypedData_Get_Struct(self, struct packcr_context_data, &packcr_context_data_type, packcr_context);

    path = rb_check_string_type(arg);
    if (NIL_P(path)) {
        rb_raise(rb_eArgError, "bad path: %"PRIsVALUE, rb_inspect(arg));
    }

    opts.ascii = FALSE;
    opts.lines = FALSE;
    opts.debug = FALSE;
    packcr_context->ctx = create_context(RSTRING_PTR(path), NULL, &opts);

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
    return parse(packcr_context->ctx) ? Qtrue : Qfalse;
}

static VALUE packcr_context_generate(VALUE self) {
    struct packcr_context_data *packcr_context;

    TypedData_Get_Struct(self, struct packcr_context_data, &packcr_context_data_type, packcr_context);

    if (!packcr_context->ctx) {
        rb_raise(rb_eRuntimeError, "closed context");
    }
    return generate(packcr_context->ctx) ? Qtrue : Qfalse;
}

static VALUE packcr_context_destroy(VALUE self) {
    struct packcr_context_data *packcr_context;

    TypedData_Get_Struct(self, struct packcr_context_data, &packcr_context_data_type, packcr_context);

    packcr_context_struct_free(packcr_context);
    return self;
}

void Init_packcr(void) {
    VALUE cPackcr, cPackcr_Context;

    cPackcr = rb_const_get(rb_cObject, rb_intern("Packcr"));

    cPackcr_Context = rb_define_class_under(rb_cObject, "Context", cPackcr);
    rb_define_alloc_func(cPackcr_Context, packcr_context_s_alloc);
    rb_define_method(cPackcr_Context, "initialize", packcr_context_initialize, 1);
    rb_define_method(cPackcr_Context, "parse", packcr_context_parse, 0);
    rb_define_method(cPackcr_Context, "generate", packcr_context_generate, 0);
    rb_define_method(cPackcr_Context, "destroy", packcr_context_destroy, 0);
}
