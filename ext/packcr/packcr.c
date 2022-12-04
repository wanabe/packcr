#include <ruby.h>
#include "packcc/packcc.c"

static VALUE packcr_run(VALUE self) {
    VALUE path = rb_iv_get(self, "@path");
    const char *iname = RSTRING_PTR(path);
    options_t opts;
    opts.ascii = FALSE;
    opts.lines = FALSE;
    opts.debug = FALSE;
    {
        context_t *const ctx = create_context(iname, NULL, &opts);
        const int b = parse(ctx) && generate(ctx);
        destroy_context(ctx);
        if (!b) {
            rb_raise(rb_eRuntimeError, "PackCC error");
        };
    }
    return self;
}

void Init_packcr(void) {
  VALUE cPackcr;
 
  cPackcr = rb_const_get(rb_cObject, rb_intern("Packcr"));

  rb_define_method(cPackcr, "run", packcr_run, 0);
}
