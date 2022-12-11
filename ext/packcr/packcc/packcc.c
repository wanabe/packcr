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
    node_t **buf;
    size_t max;
    size_t len;
} node_array_t;

typedef struct node_const_array_tag {
    const node_t **buf;
    size_t max;
    size_t len;
} node_const_array_t;

typedef struct node_rule_tag {
    char *name;
    node_t *expr;
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
    const node_t *rule;
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
    node_t *expr;
} node_quantity_t;

typedef struct node_predicate_tag {
    bool_t neg;
    node_t *expr;
} node_predicate_t;

typedef struct node_sequence_tag {
    node_array_t nodes;
} node_sequence_t;

typedef struct node_alternate_tag {
    node_array_t nodes;
} node_alternate_t;

typedef struct node_capture_tag {
    node_t *expr;
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
    node_t *expr;
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

static void *realloc_e(void *ptr, size_t size) {
    void *const p = realloc(ptr, size);
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

static size_t string_to_size_t(const char *str) {
#define N (~(size_t)0 / 10)
#define M (~(size_t)0 - 10 * N)
    size_t n = 0, i, k;
    for (i = 0; str[i]; i++) {
        const char c = str[i];
        if (c < '0' || c > '9') return VOID_VALUE;
        k = (size_t)(c - '0');
        if (n >= N && k > M) return VOID_VALUE; /* overflow */
        n = k + 10 * n;
    }
    return n;
#undef N
#undef M
}

static size_t find_first_trailing_space(const char *str, size_t start, size_t end, size_t *next) {
    size_t j = start, i;
    for (i = start; i < end; i++) {
        switch (str[i]) {
        case ' ':
        case '\v':
        case '\f':
        case '\t':
            continue;
        case '\n':
            if (next) *next = i + 1;
            return j;
        case '\r':
            if (i + 1 < end && str[i + 1] == '\n') i++;
            if (next) *next = i + 1;
            return j;
        default:
            j = i + 1;
        }
    }
    if (next) *next = end;
    return j;
}

static size_t count_indent_spaces(const char *str, size_t start, size_t end, size_t *next) {
    size_t n = 0, i;
    for (i = start; i < end; i++) {
        switch (str[i]) {
        case ' ':
        case '\v':
        case '\f':
            n++;
            break;
        case '\t':
            n = (n + 8) & ~7;
            break;
        default:
            if (next) *next = i;
            return n;
        }
    }
    if (next) *next = end;
    return n;
}

static size_t find_trailing_blanks(const char *str) {
    size_t i, j;
    for (j = 0, i = 0; str[i]; i++) {
        if (
            str[i] != ' '  &&
            str[i] != '\v' &&
            str[i] != '\f' &&
            str[i] != '\t' &&
            str[i] != '\n' &&
            str[i] != '\r'
        ) j = i + 1;
    }
    return j;
}

__attribute__((format(printf, 2, 3)))
static int stream__printf(VALUE stream, const char *format, ...) {
    {
#define M 1024
        char s[M], *p = NULL;
        int n = 0;
        size_t l = 0;
        {
            va_list a;
            va_start(a, format);
            n = vsnprintf(NULL, 0, format, a);
            va_end(a);
            if (n < 0) {
                print_error("Internal error\n");
                exit(2);
            }
            l = (size_t)n + 1;
        }
        p = (l > M) ? (char *)malloc_e(l) : s;
        {
            va_list a;
            va_start(a, format);
            n = vsnprintf(p, l, format, a);
            va_end(a);
            if (n < 0 || (size_t)n >= l) {
                print_error("Internal error\n");
                exit(2);
            }
        }
        rb_funcall(stream, rb_intern("write"), 1, rb_str_new2(p));
        if (p != s) free(p);
        return n;
#undef M
    }
}

static void stream__write_code_block(VALUE stream, VALUE rcode, size_t indent, const char *fname) {
    bool_t b = FALSE;
    size_t i, j, k;
    const char *ptr;
    size_t len;
    size_t lineno;
    code_block_t *code_block;
    TypedData_Get_Struct(rcode, code_block_t, &packcr_ptr_data_type, code_block);
    ptr = code_block->text;
    len = code_block->len;
    lineno = code_block->line;
    if (len == VOID_VALUE) return; /* for safety */
    j = find_first_trailing_space(ptr, 0, len, &k);
    for (i = 0; i < j; i++) {
        if (
            ptr[i] != ' '  &&
            ptr[i] != '\v' &&
            ptr[i] != '\f' &&
            ptr[i] != '\t'
        ) break;
    }
    if (i < j) {
        VALUE rline = rb_ivar_get(stream, rb_intern("@line"));
        if (!NIL_P(rline))
            rb_funcall(stream, rb_intern("write_line_directive"), 2, rb_str_new2(fname), SIZET2NUM(lineno));
        if (ptr[i] != '#')
            rb_funcall(stream, rb_intern("write_characters"), 2, SIZET2NUM(' '), SIZET2NUM(indent));
        rb_funcall(stream, rb_intern("write_text"), 1, rb_str_new(ptr + i, j - i));
        rb_funcall(stream, rb_intern("putc"), 1, INT2NUM('\n'));
        b = TRUE;
    }
    else {
        lineno++;
    }
    if (k < len) {
        size_t m = VOID_VALUE;
        size_t h;
        for (i = k; i < len; i = h) {
            j = find_first_trailing_space(ptr, i, len, &h);
            if (i < j) {
                VALUE rline = rb_ivar_get(stream, rb_intern("@line"));
                if (!NIL_P(rline) && !b)
                    rb_funcall(stream, rb_intern("write_line_directive"), 2, rb_str_new2(fname), SIZET2NUM(lineno));
                if (ptr[i] != '#') {
                    const size_t l = count_indent_spaces(ptr, i, j, NULL);
                    if (m == VOID_VALUE || m > l) m = l;
                }
                b = TRUE;
            }
            else {
                if (!b) {
                    k = h;
                    lineno++;
                }
            }
        }
        for (i = k; i < len; i = h) {
            j = find_first_trailing_space(ptr, i, len, &h);
            if (i < j) {
                const size_t l = count_indent_spaces(ptr, i, j, &i);
                if (ptr[i] != '#') {
                    assert(m != VOID_VALUE); /* m must have a valid value */
                    assert(l >= m);
                    rb_funcall(stream, rb_intern("write_characters"), 2, SIZET2NUM(' '), SIZET2NUM(l - m + indent));
                }
                rb_funcall(stream, rb_intern("write_text"), 1, rb_str_new(ptr + i, j - i));
                rb_funcall(stream, rb_intern("putc"), 1, INT2NUM('\n'));
                b = TRUE;
            }
            else if (h < len) {
                rb_funcall(stream, rb_intern("putc"), 1, INT2NUM('\n'));
            }
        }
    }
    {
        VALUE rline = rb_ivar_get(stream, rb_intern("@line"));
        if (!NIL_P(rline) && b) {
            VALUE rname = rb_ivar_get(stream, rb_intern("@name"));
            rb_funcall(stream, rb_intern("write_line_directive"), 2, rname, rline);
        }
    }
}

static void code_block__init(code_block_t *code) {
    code->text = NULL;
    code->len = 0;
    code->line = VOID_VALUE;
    code->col = VOID_VALUE;
}

static void code_block__term(code_block_t *code) {
    free(code->text);
}

static void node_array__init(node_array_t *array) {
    array->len = 0;
    array->max = 0;
    array->buf = NULL;
}

static void node_array__add(node_array_t *array, node_t *node) {
    if (array->max <= array->len) {
        const size_t n = array->len + 1;
        size_t m = array->max;
        if (m == 0) m = ARRAY_MIN_SIZE;
        while (m < n && m != 0) m <<= 1;
        if (m == 0) m = n; /* in case of shift overflow */
        array->buf = (node_t **)realloc_e(array->buf, sizeof(node_t *) * m);
        array->max = m;
    }
    array->buf[array->len++] = node;
}

static void destroy_node(node_t *node);

static void node_array__term(node_array_t *array) {
    while (array->len > 0) {
        array->len--;
        destroy_node(array->buf[array->len]);
    }
    free(array->buf);
}

static void node_const_array__init(node_const_array_t *array) {
    array->len = 0;
    array->max = 0;
    array->buf = NULL;
}

static void node_const_array__add(node_const_array_t *array, const node_t *node) {
    if (array->max <= array->len) {
        const size_t n = array->len + 1;
        size_t m = array->max;
        if (m == 0) m = ARRAY_MIN_SIZE;
        while (m < n && m != 0) m <<= 1;
        if (m == 0) m = n; /* in case of shift overflow */
        array->buf = (const node_t **)realloc_e((node_t **)array->buf, sizeof(const node_t *) * m);
        array->max = m;
    }
    array->buf[array->len++] = node;
}

static void node_const_array__clear(node_const_array_t *array) {
    array->len = 0;
}

static void node_const_array__term(node_const_array_t *array) {
    free((node_t **)array->buf);
}

static VALUE create_rule_node() {
    VALUE rnode = rb_funcall(cPackcr_Node, rb_intern("new"), 0);
    node_t *node;
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node->type = NODE_RULE;
    rb_funcall(rnode, rb_intern("name="), 1, Qnil);
    rb_funcall(rnode, rb_intern("expr="), 1, Qnil);;
    rb_funcall(rnode, rb_intern("ref="), 1, SIZET2NUM(0));
    node_const_array__init(&node->data.rule.vars);
    node_const_array__init(&node->data.rule.capts);
    rb_funcall(rnode, rb_intern("vars="), 1, rb_ary_new());
    rb_funcall(rnode, rb_intern("capts="), 1, rb_ary_new());
    rb_funcall(rnode, rb_intern("line="), 1, SIZET2NUM(VOID_VALUE));
    rb_funcall(rnode, rb_intern("col="), 1, SIZET2NUM(VOID_VALUE));
    return rnode;
}

static VALUE create_action_node() {
    VALUE rnode = rb_funcall(cPackcr_Node, rb_intern("new"), 0);
    node_t *node;
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node->type = NODE_ACTION;
    code_block__init(&node->data.action.code);
    rb_funcall(rnode, rb_intern("index="), 1, SIZET2NUM(VOID_VALUE));
    node_const_array__init(&node->data.action.vars);
    node_const_array__init(&node->data.action.capts);
    rb_funcall(rnode, rb_intern("vars="), 1, rb_ary_new());
    rb_funcall(rnode, rb_intern("capts="), 1, rb_ary_new());
    return rnode;
}

static VALUE create_error_node() {
    VALUE rnode = rb_funcall(cPackcr_Node, rb_intern("new"), 0);
    node_t *node;
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node->type = NODE_ERROR;
    rb_funcall(rnode, rb_intern("expr="), 1, Qnil);;
    code_block__init(&node->data.error.code);
    rb_funcall(rnode, rb_intern("index="), 1, SIZET2NUM(VOID_VALUE));
    node_const_array__init(&node->data.error.vars);
    node_const_array__init(&node->data.error.capts);
    rb_funcall(rnode, rb_intern("vars="), 1, rb_ary_new());
    rb_funcall(rnode, rb_intern("capts="), 1, rb_ary_new());
    return rnode;
}

static VALUE create_reference_node() {
    VALUE rnode = rb_funcall(cPackcr_Node, rb_intern("new"), 0);
    node_t *node;
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node->type = NODE_REFERENCE;
    rb_funcall(rnode, rb_intern("var="), 1, Qnil);
    node->data.reference.var = NULL;
    rb_funcall(rnode, rb_intern("index="), 1, SIZET2NUM(VOID_VALUE));
    rb_funcall(rnode, rb_intern("name="), 1, Qnil);
    node->data.reference.rule = NULL;
    rb_funcall(rnode, rb_intern("line="), 1, SIZET2NUM(VOID_VALUE));
    rb_funcall(rnode, rb_intern("col="), 1, SIZET2NUM(VOID_VALUE));
    return rnode;
}

static VALUE create_string_node() {
    VALUE rnode = rb_funcall(cPackcr_Node, rb_intern("new"), 0);
    node_t *node;
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node->type = NODE_STRING;
    node->data.string.value = NULL;
    return rnode;
}

static VALUE create_charclass_node() {
    VALUE rnode = rb_funcall(cPackcr_Node, rb_intern("new"), 0);
    node_t *node;
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node->type = NODE_CHARCLASS;
    node->data.charclass.value = NULL;
    return rnode;
}

static VALUE create_quantity_node() {
    VALUE rnode = rb_funcall(cPackcr_Node, rb_intern("new"), 0);
    node_t *node;
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node->type = NODE_QUANTITY;
    node->data.quantity.min = node->data.quantity.max = 0;
    rb_funcall(rnode, rb_intern("expr="), 1, Qnil);;
    return rnode;
}

static VALUE create_predicate_node() {
    VALUE rnode = rb_funcall(cPackcr_Node, rb_intern("new"), 0);
    node_t *node;
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node->type = NODE_PREDICATE;
    node->data.predicate.neg = FALSE;
    rb_funcall(rnode, rb_intern("expr="), 1, Qnil);;
    return rnode;
}

static VALUE create_sequence_node() {
    VALUE rnode = rb_funcall(cPackcr_Node, rb_intern("new"), 0);
    node_t *node;
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node->type = NODE_SEQUENCE;
    node_array__init(&node->data.sequence.nodes);
    rb_ivar_set(rnode, rb_intern("@nodes"), rb_ary_new());
    return rnode;
}

static VALUE create_alternate_node() {
    VALUE rnode = rb_funcall(cPackcr_Node, rb_intern("new"), 0);
    node_t *node;
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node->type = NODE_ALTERNATE;
    node_array__init(&node->data.alternate.nodes);
    rb_ivar_set(rnode, rb_intern("@nodes"), rb_ary_new());
    return rnode;
}

static VALUE create_capture_node() {
    VALUE rnode = rb_funcall(cPackcr_Node, rb_intern("new"), 0);
    node_t *node;
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node->type = NODE_CAPTURE;
    rb_funcall(rnode, rb_intern("expr="), 1, Qnil);;
    rb_funcall(rnode, rb_intern("index="), 1, SIZET2NUM(VOID_VALUE));
    return rnode;
}

static VALUE create_expand_node() {
    VALUE rnode = rb_funcall(cPackcr_Node, rb_intern("new"), 0);
    node_t *node;
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node->type = NODE_EXPAND;
    rb_funcall(rnode, rb_intern("index="), 1, SIZET2NUM(VOID_VALUE));
    rb_funcall(rnode, rb_intern("line="), 1, SIZET2NUM(VOID_VALUE));
    rb_funcall(rnode, rb_intern("col="), 1, SIZET2NUM(VOID_VALUE));
    return rnode;
}

static void destroy_node(node_t *node) {
    if (node == NULL) return;
    switch (node->type) {
    case NODE_RULE:
        node_const_array__term(&node->data.rule.capts);
        node_const_array__term(&node->data.rule.vars);
        destroy_node(node->data.rule.expr);
        free(node->data.rule.name);
        break;
    case NODE_REFERENCE:
        free(node->data.reference.name);
        free(node->data.reference.var);
        break;
    case NODE_STRING:
        free(node->data.string.value);
        break;
    case NODE_CHARCLASS:
        free(node->data.charclass.value);
        break;
    case NODE_QUANTITY:
        destroy_node(node->data.quantity.expr);
        break;
    case NODE_PREDICATE:
        destroy_node(node->data.predicate.expr);
        break;
    case NODE_SEQUENCE:
        node_array__term(&node->data.sequence.nodes);
        break;
    case NODE_ALTERNATE:
        node_array__term(&node->data.alternate.nodes);
        break;
    case NODE_CAPTURE:
        destroy_node(node->data.capture.expr);
        break;
    case NODE_EXPAND:
        break;
    case NODE_ACTION:
        node_const_array__term(&node->data.action.capts);
        node_const_array__term(&node->data.action.vars);
        code_block__term(&node->data.action.code);
        break;
    case NODE_ERROR:
        node_const_array__term(&node->data.error.capts);
        node_const_array__term(&node->data.error.vars);
        code_block__term(&node->data.error.code);
        destroy_node(node->data.error.expr);
        break;
    default:
        print_error("Internal error [%d]\n", __LINE__);
        exit(-1);
    }
}

static VALUE parse_expression(VALUE rctx, VALUE rrule);

static VALUE parse_primary(VALUE rctx, VALUE rrule) {
    const size_t p = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
    const size_t l = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
    const size_t m = NUM2SIZET(rb_funcall(rctx, rb_intern("column_number"), 0));
    const size_t n = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@charnum")));
    const size_t o = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linepos")));
    VALUE rn_p;
    VALUE rbuffer = rb_ivar_get(rctx, rb_intern("@buffer"));
    if (RB_TEST(rb_funcall(rctx, rb_intern("match_identifier"), 0))) {
        const size_t q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
        size_t r = VOID_VALUE, s = VOID_VALUE;
        RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
        if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM(':')))) {
            RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
            r = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
            if (!RB_TEST(rb_funcall(rctx, rb_intern("match_identifier"), 0))) goto EXCEPTION;
            s = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
            RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
        }
        if (RB_TEST(rb_funcall(rctx, rb_intern("match_string"), 1, rb_str_new_cstr("<-")))) goto EXCEPTION;
        rn_p = create_reference_node();
        if (r == VOID_VALUE) {
            VALUE rname = rb_funcall(rbuffer, rb_intern("to_s"), 0);
            rname = rb_funcall(rname, rb_intern("[]"), 2, SIZET2NUM(p), SIZET2NUM(q - p));
            assert(q >= p);
            rb_funcall(rn_p, rb_intern("var="), 1, Qnil);
            rb_funcall(rn_p, rb_intern("index="), 1, SIZET2NUM(VOID_VALUE));
            rb_funcall(rn_p, rb_intern("name="), 1, rname);
        }
        else {
            VALUE rvar = rb_funcall(rbuffer, rb_intern("to_s"), 0);
            rvar = rb_funcall(rvar, rb_intern("[]"), 2, SIZET2NUM(p), SIZET2NUM(q - p));
            assert(s != VOID_VALUE); /* s should have a valid value when r has a valid value */
            assert(q >= p);
            rb_funcall(rn_p, rb_intern("var="), 1, rvar);
            if ((char)NUM2SIZET(rb_funcall(rvar, rb_intern("ord"), 0)) == '_') {
                print_error("%s:" FMT_LU ":" FMT_LU ": Leading underscore in variable name '%s'\n",
                    RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1), StringValuePtr(rvar));
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
            }
            {
                size_t i;
                VALUE rvars = rb_funcall(rrule, rb_intern("vars"), 0);
                for (i = 0; i < (size_t)RARRAY_LEN(rvars); i++) {
                    VALUE rvar2 = rb_funcall(rb_ary_entry(rvars, i), rb_intern("var"), 0);
                    //assert(rule->data.rule.vars.buf[i]->type == NODE_REFERENCE);
                    if (RB_TEST(rb_funcall(rvar, rb_intern("=="), 1, rvar2))) break;
                }
                if (i == (size_t)RARRAY_LEN(rvars)) rb_funcall(rrule, rb_intern("add_var"), 1, rn_p);
                rb_funcall(rn_p, rb_intern("index="), 1, SIZET2NUM(i));
            }
            assert(s >= r);
            {
                VALUE rname = rb_funcall(rbuffer, rb_intern("to_s"), 0);
                rname = rb_funcall(rname, rb_intern("[]"), 2, SIZET2NUM(r), SIZET2NUM(s - r));
                rb_funcall(rn_p, rb_intern("name="), 1, rname);
            }
        }
        rb_funcall(rn_p, rb_intern("line="), 1, SIZET2NUM(l));
        rb_funcall(rn_p, rb_intern("col="), 1, SIZET2NUM(m));
    }
    else if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('(')))) {
        RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
        rn_p = parse_expression(rctx, rrule);
        if (NIL_P(rn_p)) {
            goto EXCEPTION;
        }
        if (!RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM(')')))) goto EXCEPTION;
        RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
    }
    else if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('<')))) {
        VALUE rcapts = rb_funcall(rrule, rb_intern("capts"), 0);
        RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
        rn_p = create_capture_node();
        rb_funcall(rn_p, rb_intern("index="), 1, SIZET2NUM(RARRAY_LEN(rcapts)));
        rb_funcall(rrule, rb_intern("add_capt"), 1, rn_p);
        {
            VALUE rexpr = parse_expression(rctx, rrule);
            rb_funcall(rn_p, rb_intern("expr="), 1, rexpr);
            if (NIL_P(rexpr) || !RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('>')))) {
                //rule->data.rule.capts.len = n_p->data.capture.index;
                goto EXCEPTION;
            }
        }
        RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
    }
    else if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('$')))) {
        size_t p;
        RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
        p = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
        if (RB_TEST(rb_funcall(rctx, rb_intern("match_number"), 0))) {
            const size_t q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
            char *s;
            VALUE rs = rb_funcall(rbuffer, rb_intern("to_s"), 0);
            VALUE rindex;
            rs = rb_funcall(rs, rb_intern("[]"), 2, SIZET2NUM(p), SIZET2NUM(q - p));
            s = StringValuePtr(rs);
            RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
            rn_p = create_expand_node();
            assert(q >= p);
            s = strndup_e(s, strlen(s));
            rindex = SIZET2NUM(string_to_size_t(s));
            rb_funcall(rn_p, rb_intern("index="), 1, rindex);
            if (NUM2SIZET(rindex) == VOID_VALUE) {
                print_error("%s:" FMT_LU ":" FMT_LU ": Invalid unsigned number '%s'\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1), s);
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
            }
            else if (NUM2SIZET(rindex) == 0) {
                print_error("%s:" FMT_LU ":" FMT_LU ": 0 not allowed\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1));
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
            }
            else if (s[0] == '0') {
                print_error("%s:" FMT_LU ":" FMT_LU ": 0-prefixed number not allowed\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1));
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
                rb_funcall(rn_p, rb_intern("index="), 1, SIZET2NUM(0));
            }
            free(s);
            if (NUM2SIZET(rindex) > 0 && NUM2SIZET(rindex) != VOID_VALUE) {
                rb_funcall(rn_p, rb_intern("index="), 1, SIZET2NUM(NUM2SIZET(rindex) - 1));
                rb_funcall(rn_p, rb_intern("line="), 1, SIZET2NUM(l));
                rb_funcall(rn_p, rb_intern("col="), 1, SIZET2NUM(m));
            }
        }
        else {
            goto EXCEPTION;
        }
    }
    else if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('.')))) {
        RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
        rn_p = create_charclass_node();
        rb_funcall(rn_p, rb_intern("value="), 1, Qnil);
        if (!RB_TEST(rb_ivar_get(rctx, rb_intern("@ascii")))) {
            rb_ivar_set(rctx, rb_intern("@utf8"), Qtrue);
        }
    }
    else if (RB_TEST(rb_funcall(rctx, rb_intern("match_character_class"), 0))) {
        const size_t q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
        VALUE rcharclass = rb_funcall(rbuffer, rb_intern("to_s"), 0);
        rcharclass = rb_funcall(rcharclass, rb_intern("[]"), 2, SIZET2NUM(p + 1), SIZET2NUM(q - p - 2));
        RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
        rn_p = create_charclass_node();
        rb_funcall(cPackcr, rb_intern("unescape_string"), 2, rcharclass, Qtrue);
        if (!RB_TEST(rb_ivar_get(rctx, rb_intern("@ascii")))) {
            rb_funcall(rcharclass, rb_intern("force_encoding"), 1, rb_str_new_cstr("utf-8"));
        }
        if (!RB_TEST(rb_ivar_get(rctx, rb_intern("@ascii"))) && !RB_TEST(rb_funcall(rcharclass, rb_intern("valid_encoding?"), 0))) {
            print_error("%s:" FMT_LU ":" FMT_LU ": Invalid UTF-8 string\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1));
            rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
        }
        if (!RB_TEST(rb_ivar_get(rctx, rb_intern("@ascii"))) && !RB_TEST(rb_funcall(rcharclass, rb_intern("empty?"), 0))) {
            rb_ivar_set(rctx, rb_intern("@utf8"), Qtrue);
        }
        rb_funcall(rn_p, rb_intern("value="), 1, rcharclass);
    }
    else if (RB_TEST(rb_funcall(rctx, rb_intern("match_quotation_single"), 0)) || RB_TEST(rb_funcall(rctx, rb_intern("match_quotation_double"), 0))) {
        const size_t q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
        VALUE rstring = rb_funcall(rbuffer, rb_intern("to_s"), 0);
        rstring = rb_funcall(rstring, rb_intern("[]"), 2, SIZET2NUM(p + 1), SIZET2NUM(q - p - 2));
        RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
        rn_p = create_string_node();
        rb_funcall(cPackcr, rb_intern("unescape_string"), 2, rstring, Qtrue);
        if (!RB_TEST(rb_ivar_get(rctx, rb_intern("@ascii")))) {
            rb_funcall(rstring, rb_intern("force_encoding"), 1, rb_str_new_cstr("utf-8"));
        }
        if (!RB_TEST(rb_ivar_get(rctx, rb_intern("@ascii"))) && !RB_TEST(rb_funcall(rstring, rb_intern("valid_encoding?"), 0))) {
            print_error("%s:" FMT_LU ":" FMT_LU ": Invalid UTF-8 string\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1));
            rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
        }
        rb_funcall(rn_p, rb_intern("value="), 1, rstring);
    }
    else if (RB_TEST(rb_funcall(rctx, rb_intern("match_code_block"), 0))) {
        const size_t q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
        VALUE rcodes, rcode;
        VALUE rtext = rb_funcall(rbuffer, rb_intern("to_s"), 0);
        rtext = rb_funcall(rtext, rb_intern("[]"), 2, SIZET2NUM(p + 1), SIZET2NUM(q - p - 2));
        rcodes = rb_ivar_get(rrule, rb_intern("@codes"));
        RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
        rn_p = create_action_node();
        rcode = rb_funcall(rn_p, rb_intern("code"), 0);
        rb_funcall(rcode, rb_intern("init"), 4, rtext, SIZET2NUM(find_trailing_blanks(StringValuePtr(rtext))), SIZET2NUM(l), SIZET2NUM(m));
        rb_funcall(rn_p, rb_intern("index="), 1, SIZET2NUM(NUM2SIZET(rb_funcall(rcodes, rb_intern("length"), 0))));
        rb_ary_push(rcodes, rn_p);
    }
    else {
        goto EXCEPTION;
    }
    return rn_p;

EXCEPTION:;
    rb_ivar_set(rctx, rb_intern("@bufcur"), SIZET2NUM(p));
    rb_ivar_set(rctx, rb_intern("@linenum"), SIZET2NUM(l));
    rb_ivar_set(rctx, rb_intern("@charnum"), SIZET2NUM(n));
    rb_ivar_set(rctx, rb_intern("@linepos"), SIZET2NUM(o));
    return Qnil;
}

static VALUE parse_term(VALUE rctx, VALUE rrule) {
    const size_t p = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
    const size_t l = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
    const size_t n = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@charnum")));
    const size_t o = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linepos")));
    VALUE rn_p, rn_r, rn_q, rn_t;
    const char t = RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('&'))) ? '&' : RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('!'))) ? '!' : '\0';
    VALUE rbuffer = rb_ivar_get(rctx, rb_intern("@buffer"));
    if (t) RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
    rn_p = parse_primary(rctx, rrule);
    if (NIL_P(rn_p)) goto EXCEPTION;
    if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('*')))) {
        RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
        rn_q = create_quantity_node();
        rb_funcall(rn_q, rb_intern("min="), 1, INT2NUM(0));
        rb_funcall(rn_q, rb_intern("max="), 1, INT2NUM(-1));
        rb_funcall(rn_q, rb_intern("expr="), 1, rn_p);
    }
    else if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('+')))) {
        RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
        rn_q = create_quantity_node();
        rb_funcall(rn_q, rb_intern("min="), 1, INT2NUM(1));
        rb_funcall(rn_q, rb_intern("max="), 1, INT2NUM(-1));
        rb_funcall(rn_q, rb_intern("expr="), 1, rn_p);
    }
    else if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('?')))) {
        RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
        rn_q = create_quantity_node();
        rb_funcall(rn_q, rb_intern("min="), 1, INT2NUM(0));
        rb_funcall(rn_q, rb_intern("max="), 1, INT2NUM(1));
        rb_funcall(rn_q, rb_intern("expr="), 1, rn_p);
    }
    else {
        rn_q = rn_p;
    }
    switch (t) {
    case '&':
        rn_r = create_predicate_node();
        rb_funcall(rn_r, rb_intern("neg="), 1, Qfalse);
        rb_funcall(rn_r, rb_intern("expr="), 1, rn_q);
        break;
    case '!':
        rn_r = create_predicate_node();
        rb_funcall(rn_r, rb_intern("neg="), 1, Qtrue);
        rb_funcall(rn_r, rb_intern("expr="), 1, rn_q);
        break;
    default:
        rn_r = rn_q;
    }
    if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('~')))) {
        size_t p, l, m;
        RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
        p = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
        l = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
        m = NUM2SIZET(rb_funcall(rctx, rb_intern("column_number"), 0));
        if (RB_TEST(rb_funcall(rctx, rb_intern("match_code_block"), 0))) {
            const size_t q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
            VALUE rcode, rcodes = rb_ivar_get(rrule, rb_intern("@codes"));
            VALUE rtext = rb_funcall(rbuffer, rb_intern("to_s"), 0);
            rtext = rb_funcall(rtext, rb_intern("[]"), 2, SIZET2NUM(p + 1), SIZET2NUM(q - p - 2));
            RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
            rn_t = create_error_node();
            rb_funcall(rn_t, rb_intern("expr="), 1, rn_r);
            rcode = rb_funcall(rn_t, rb_intern("code"), 0);
            rb_funcall(rcode, rb_intern("init"), 4, rtext, SIZET2NUM(find_trailing_blanks(StringValuePtr(rtext))), SIZET2NUM(l), SIZET2NUM(m));
            rb_funcall(rn_t, rb_intern("index="), 1, SIZET2NUM(NUM2SIZET(rb_funcall(rcodes, rb_intern("length"), 0))));
            rb_ary_push(rcodes, rn_t);
        }
        else {
            goto EXCEPTION;
        }
    }
    else {
        rn_t = rn_r;
    }
    return rn_t;

EXCEPTION:;
    rb_ivar_set(rctx, rb_intern("@bufcur"), SIZET2NUM(p));
    rb_ivar_set(rctx, rb_intern("@linenum"), SIZET2NUM(l));
    rb_ivar_set(rctx, rb_intern("@charnum"), SIZET2NUM(n));
    rb_ivar_set(rctx, rb_intern("@linepos"), SIZET2NUM(o));
    return Qnil;
}

static VALUE parse_sequence(VALUE rctx, VALUE rrule) {
    const size_t p = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
    const size_t l = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
    const size_t n = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@charnum")));
    const size_t o = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linepos")));
    VALUE rn_t, rn_u, rn_s;
    rn_t = parse_term(rctx, rrule);
    if (NIL_P(rn_t)) {
        goto EXCEPTION;
    }
    rn_u = parse_term(rctx, rrule);
    if (!NIL_P(rn_u)) {
        rn_s = create_sequence_node();
        rb_funcall(rn_s, rb_intern("add_node"), 1, rn_t);
        rb_funcall(rn_s, rb_intern("add_node"), 1, rn_u);
        while (!NIL_P(rn_t = parse_term(rctx, rrule))) {
            rb_funcall(rn_s, rb_intern("add_node"), 1, rn_t);
        }
    }
    else {
        rn_s = rn_t;
    }
    return rn_s;

EXCEPTION:;
    rb_ivar_set(rctx, rb_intern("@bufcur"), SIZET2NUM(p));
    rb_ivar_set(rctx, rb_intern("@linenum"), SIZET2NUM(l));
    rb_ivar_set(rctx, rb_intern("@charnum"), SIZET2NUM(n));
    rb_ivar_set(rctx, rb_intern("@linepos"), SIZET2NUM(o));
    return Qnil;
}

static VALUE parse_expression(VALUE rctx, VALUE rrule) {
    const size_t p = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
    const size_t l = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
    const size_t n = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@charnum")));
    const size_t o = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linepos")));
    size_t q;
    VALUE rn_e, rn_s;
    rn_s = parse_sequence(rctx, rrule);
    if (NIL_P(rn_s)) goto EXCEPTION;
    q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
    if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('/')))) {
        rb_ivar_set(rctx, rb_intern("@bufcur"), SIZET2NUM(q));
        rn_e = create_alternate_node();
        rb_funcall(rn_e, rb_intern("add_node"), 1, rn_s);
        while (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('/')))) {
            RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
            rn_s = parse_sequence(rctx, rrule);
            if (NIL_P(rn_s)) goto EXCEPTION;
            rb_funcall(rn_e, rb_intern("add_node"), 1, rn_s);
        }
    }
    else {
        rn_e = rn_s;
    }
    return rn_e;

EXCEPTION:;
    rb_ivar_set(rctx, rb_intern("@bufcur"), SIZET2NUM(p));
    rb_ivar_set(rctx, rb_intern("@linenum"), SIZET2NUM(l));
    rb_ivar_set(rctx, rb_intern("@charnum"), SIZET2NUM(n));
    rb_ivar_set(rctx, rb_intern("@linepos"), SIZET2NUM(o));
    return Qnil;
}

static VALUE parse_rule(VALUE rctx) {
    const size_t p = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
    const size_t l = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
    const size_t m = NUM2SIZET(rb_funcall(rctx, rb_intern("column_number"), 0));
    const size_t n = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@charnum")));
    const size_t o = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linepos")));
    size_t q;
    VALUE rbuffer = rb_ivar_get(rctx, rb_intern("@buffer"));
    VALUE rn_r;
    VALUE rname;
    if (!RB_TEST(rb_funcall(rctx, rb_intern("match_identifier"), 0))) goto EXCEPTION;
    q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
    RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
    if (!RB_TEST(rb_funcall(rctx, rb_intern("match_string"), 1, rb_str_new_cstr("<-")))) goto EXCEPTION;
    RB_TEST(rb_funcall(rctx, rb_intern("match_spaces"), 0));
    rn_r = create_rule_node();
    {
        VALUE rexpr = parse_expression(rctx, rn_r);
        rb_funcall(rn_r, rb_intern("expr="), 1, rexpr);
        if (NIL_P(rexpr)) {
            goto EXCEPTION;
        }
    }
    assert(q >= p);
    rname = rb_funcall(rbuffer, rb_intern("to_s"), 0);
    rname = rb_funcall(rname, rb_intern("[]"), 2, SIZET2NUM(p), SIZET2NUM(q - p));
    rb_funcall(rn_r, rb_intern("name="), 1, rname);
    rb_funcall(rn_r, rb_intern("line="), 1, SIZET2NUM(l));
    rb_funcall(rn_r, rb_intern("col="), 1, SIZET2NUM(m));
    return rn_r;

EXCEPTION:;
    rb_ivar_set(rctx, rb_intern("@bufcur"), SIZET2NUM(p));
    rb_ivar_set(rctx, rb_intern("@linenum"), SIZET2NUM(l));
    rb_ivar_set(rctx, rb_intern("@charnum"), SIZET2NUM(n));
    rb_ivar_set(rctx, rb_intern("@linepos"), SIZET2NUM(o));
    return Qnil;
}
