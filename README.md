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