/*
 * PackCC: a packrat parser generator for C.
 *
 * Copyright (c) 2014, 2019-2022 Arihiro Yoshida. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

/*
 * The algorithm is based on the paper "Packrat Parsers Can Support Left Recursion"
 * authored by A. Warth, J. R. Douglass, and T. Millstein.
 *
 * The specification is determined by referring to peg/leg developed by Ian Piumarta.
 */

#ifdef _MSC_VER
#define _CRT_SECURE_NO_WARNINGS
#ifdef _DEBUG
#define _CRTDBG_MAP_ALLOC
#include <crtdbg.h>
#endif
#endif

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <limits.h>
#include <assert.h>

#ifndef _MSC_VER
#if defined __GNUC__ && defined _WIN32 /* MinGW */
#ifndef PCC_USE_SYSTEM_STRNLEN
#define strnlen(str, maxlen) strnlen_(str, maxlen)
static size_t strnlen_(const char *str, size_t maxlen) {
    size_t i;
    for (i = 0; i < maxlen && str[i]; i++);
    return i;
}
#endif /* !PCC_USE_SYSTEM_STRNLEN */
#endif /* defined __GNUC__ && defined _WIN32 */
#endif /* !_MSC_VER */

#ifdef _MSC_VER
#define snprintf _snprintf
#define vsnprintf _vsnprintf
#define unlink _unlink
#else
#include <unistd.h> /* for unlink() */
#endif

#if !defined __has_attribute || defined _MSC_VER
#define __attribute__(x)
#endif

#undef TRUE  /* to avoid macro definition conflicts with the system header file of IBM AIX */
#undef FALSE

#define VERSION "1.8.0"

#ifndef BUFFER_MIN_SIZE
#define BUFFER_MIN_SIZE 256
#endif
#ifndef ARRAY_MIN_SIZE
#define ARRAY_MIN_SIZE 2
#endif

#define VOID_VALUE (~(size_t)0)

#ifdef _WIN64 /* 64-bit Windows including MSVC and MinGW-w64 */
#define FMT_LU "%llu"
typedef unsigned long long ulong_t;
/* NOTE: "%llu" and "long long" are not C89-compliant, but they are required to deal with a 64-bit integer value in 64-bit Windows. */
#else
#define FMT_LU "%lu"
typedef unsigned long ulong_t;
#endif
/* FMT_LU and ulong_t are used to print size_t values safely (ex. printf(FMT_LU "\n", (ulong_t)value);) */
/* NOTE: Neither "%z" nor <inttypes.h> is used since PackCC complies with the C89 standard as much as possible. */

typedef enum bool_tag {
    FALSE = 0,
    TRUE
} bool_t;

typedef struct char_array_tag {
    char *buf;
    size_t max;
    size_t len;
} char_array_t;

typedef struct code_block_tag {
    char *text;
    size_t len;
    size_t line;
    size_t col;
} code_block_t;

typedef enum node_type_tag {
    NODE_RULE = 0,
    NODE_REFERENCE,
    NODE_STRING,
    NODE_CHARCLASS,
    NODE_QUANTITY,
    NODE_PREDICATE,
    NODE_SEQUENCE,
    NODE_ALTERNATE,
    NODE_CAPTURE,
    NODE_EXPAND,
    NODE_ACTION,
    NODE_ERROR
} node_type_t;

typedef struct node_tag node_t;

typedef struct node_array_tag {
    size_t max;
    size_t len;
} node_array_t;

typedef struct node_const_array_tag {
    size_t max;
    size_t len;
} node_const_array_t;

typedef struct node_rule_tag {
    char *name;
    int ref; /* mutable */
    node_const_array_t vars;
    node_const_array_t capts;
    size_t line;
    size_t col;
} node_rule_t;

typedef struct node_reference_tag {
    char *var; /* NULL if no variable name */
    size_t index;
    char *name;
    size_t line;
    size_t col;
} node_reference_t;

typedef struct node_string_tag {
    char *value;
} node_string_t;

typedef struct node_charclass_tag {
    char *value; /* NULL means any character */
} node_charclass_t;

typedef struct node_quantity_tag {
    int min;
    int max;
} node_quantity_t;

typedef struct node_predicate_tag {
    bool_t neg;
} node_predicate_t;

typedef struct node_sequence_tag {
    node_array_t nodes;
} node_sequence_t;

typedef struct node_alternate_tag {
    node_array_t nodes;
} node_alternate_t;

typedef struct node_capture_tag {
    size_t index;
} node_capture_t;

typedef struct node_expand_tag {
    size_t index;
    size_t line;
    size_t col;
} node_expand_t;

typedef struct node_action_tag {
    code_block_t code;
    size_t index;
    node_const_array_t vars;
    node_const_array_t capts;
} node_action_t;

typedef struct node_error_tag {
    code_block_t code;
    size_t index;
    node_const_array_t vars;
    node_const_array_t capts;
} node_error_t;

typedef union node_data_tag {
    node_rule_t      rule;
    node_reference_t reference;
    node_string_t    string;
    node_charclass_t charclass;
    node_quantity_t  quantity;
    node_predicate_t predicate;
    node_sequence_t  sequence;
    node_alternate_t alternate;
    node_capture_t   capture;
    node_expand_t    expand;
    node_action_t    action;
    node_error_t     error;
} node_data_t;

struct node_tag {
    node_type_t type;
    node_data_t data;
};

typedef enum code_flag_tag {
    CODE_FLAG__NONE = 0,
    CODE_FLAG__UTF8_CHARCLASS_USED = 1
} code_flag_t;

typedef enum string_flag_tag {
    STRING_FLAG__NONE = 0,
    STRING_FLAG__NOTEMPTY = 1,
    STRING_FLAG__NOTVOID = 2,
    STRING_FLAG__IDENTIFIER = 4
} string_flag_t;

typedef enum code_reach_tag {
    CODE_REACH__BOTH = 0,
    CODE_REACH__ALWAYS_SUCCEED = 1,
    CODE_REACH__ALWAYS_FAIL = -1
} code_reach_t;

static const char *g_cmdname = "packcc"; /* replaced later with actual one */

__attribute__((format(printf, 1, 2)))
static int print_error(const char *format, ...) {
    int n;
    va_list a;
    va_start(a, format);
    n = fprintf(stderr, "%s: ", g_cmdname);
    if (n >= 0) {
        const int k = vfprintf(stderr, format, a);
        if (k < 0) n = k; else n += k;
    }
    va_end(a);
    return n;
}

static void *malloc_e(size_t size) {
    void *const p = malloc(size);
    if (p == NULL) {
        print_error("Out of memory\n");
        exit(3);
    }
    return p;
}

static char *strndup_e(const char *str, size_t len) {
    const size_t m = strnlen(str, len);
    char *const s = (char *)malloc_e(m + 1);
    memcpy(s, str, m);
    s[m] = '\0';
    return s;
}
