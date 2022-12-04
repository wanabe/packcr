#include <ruby.h>
int packcc_main(int argc, char **argv);

struct packcr_data {
    /* TODO: add the members */
};

static void packcr_mark(void *ptr) {
    /* struct packcr_data *packcr = ptr; */
    /* TODO: add the mark logic */
}

static void packcr_free(void *ptr) {
    struct packcr_data *packcr = ptr;

    /* TODO: add the free logic */
    xfree(packcr);
}

static size_t packcr_memsize(const void *ptr) {
    return sizeof(struct packcr_data);
}

static const rb_data_type_t packcr_data_type = {
    "packcr",
    {packcr_mark, packcr_free, packcr_memsize,},
    0, 0, RUBY_TYPED_WB_PROTECTED | RUBY_TYPED_FREE_IMMEDIATELY
};

static VALUE packcr_s_alloc(VALUE klass) {
    struct packcr_data *packcr;
    VALUE obj = TypedData_Make_Struct(klass, struct packcr_data, &packcr_data_type, packcr);

    /* TODO: add the initialize logic for the C struct */

    return obj;
}

static VALUE packcr_initialize(VALUE self, VALUE arg) {
    VALUE path = rb_check_string_type(arg);
    if (NIL_P(path)) {
        rb_raise(rb_eArgError, "bad path: %"PRIsVALUE, rb_inspect(arg));
    }
    rb_iv_set(self, "path", path);
    return self;
}

static VALUE packcr_run(VALUE self) {
    VALUE path = rb_iv_get(self, "path");
    const char *argv[] = {"", RSTRING_PTR(path)};
    int ret = packcc_main(2, (char**)argv);
    if (ret != 0) {
        rb_raise(rb_eRuntimeError, "PackCC error");
    }
    return self;
}

void Init_packcr(void) {
  VALUE cPackcr;
 
  cPackcr = rb_define_class("Packcr", rb_cObject);

  rb_define_alloc_func(cPackcr, packcr_s_alloc);
  rb_define_method(cPackcr, "initialize", packcr_initialize, 1);
  rb_define_method(cPackcr, "run", packcr_run, 0);
}
