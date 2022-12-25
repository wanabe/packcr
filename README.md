# PackCR

## Overview

PackCR is a parser generator for C as ruby library.
This library is a port of PackCC rewritten in ruby.
The Original PackCC is https://github.com/arithy/packcc.

## Usage

You can get Packcr object with `Packcr.new(peg_path)` and it can generate C source and header with `Packcr#run`.

Example:

```
$ cat ./tmp/example.sh
#!/bin/sh
cd $0/..
cp ../packcc/examples/calc.peg .
bundle exec ruby -rpackcr -e 'Packcr.new("calc.peg").run'
gcc calc.c
echo "1 + 2 * 3 - 4 / 2" | ./a.out

$ ./tmp/example.sh
answer=5
```

## Syntax

The syntax is almost the same as PackCC.
Additional syntax is shown below.

**`%location` `{` _c struct members_ `}`**

It defines your own location structure.
It will be extracted:

```
typedef struct pcc_location_tag {
    _c struct members_
} pcc_location_t;
```

If `%location` is defined, PEG file must have some functions in `%source`:
- `void pcc_location_init(pcc_location_t *lp)`
- `void pcc_location_forward(pcc_location_t *lp, char *buf, size_t n)`
- `pcc_location_t pcc_location_add(pcc_location_t l1, pcc_location_t l2)`
- `pcc_location_t pcc_location_sub(pcc_location_t l1, pcc_location_t l2)`

They can be `static` and/or `inline`.

Locations are captured and they can be refer with **`$`**_n_**`sl`** and **`$`**_n_**`el`**.
You can see the example [examples/calc_loc.peg](examples/calc_loc.peg).
