#include <ruby.h>
int packcc_main(int argc, char **argv);

static VALUE packcr_run(VALUE self) {
    VALUE path = rb_iv_get(self, "@path");
    const char *argv[] = {"", RSTRING_PTR(path)};
    int ret = packcc_main(2, (char**)argv);
    if (ret != 0) {
        rb_raise(rb_eRuntimeError, "PackCC error");
    }
    return self;
}

void Init_packcr(void) {
  VALUE cPackcr;
 
  cPackcr = rb_const_get(rb_cObject, rb_intern("Packcr"));

  rb_define_method(cPackcr, "run", packcr_run, 0);
}
