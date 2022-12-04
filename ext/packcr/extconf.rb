require "mkmf"

$srcs = ["packcr.c", "packcc/packcc.c"]
$VPATH << "$(srcdir)/packcc"

create_makefile "packcr"
