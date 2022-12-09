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

static bool_t is_filled_string(const char *str) {
    size_t i;
    for (i = 0; str[i]; i++) {
        if (
            str[i] != ' '  &&
            str[i] != '\v' &&
            str[i] != '\f' &&
            str[i] != '\t' &&
            str[i] != '\n' &&
            str[i] != '\r'
        ) return TRUE;
    }
    return FALSE;
}

static bool_t is_identifier_string(const char *str) {
    size_t i;
    if (!(
        (str[0] >= 'a' && str[0] <= 'z') ||
        (str[0] >= 'A' && str[0] <= 'Z') ||
        str[0] == '_'
    )) return FALSE;
    for (i = 1; str[i]; i++) {
        if (!(
            (str[i] >= 'a' && str[i] <= 'z') ||
            (str[i] >= 'A' && str[i] <= 'Z') ||
            (str[i] >= '0' && str[i] <= '9') ||
            str[i] == '_'
        )) return FALSE;
    }
    return TRUE;
}

static bool_t is_valid_utf8_string(const char *str) {
    int k = 0, n = 0, u = 0;
    size_t i;
    for (i = 0; str[i]; i++) {
        const int c = (int)(unsigned char)str[i];
        switch (k) {
        case 0:
            if (c >= 0x80) {
                if ((c & 0xe0) == 0xc0) {
                    u = c & 0x1f;
                    n = k = 1;
                }
                else if ((c & 0xf0) == 0xe0) {
                    u = c & 0x0f;
                    n = k = 2;
                }
                else if ((c & 0xf8) == 0xf0) {
                    u = c & 0x07;
                    n = k = 3;
                }
                else {
                    return FALSE;
                }
            }
            break;
        case 1:
        case 2:
        case 3:
            if ((c & 0xc0) == 0x80) {
                u <<= 6;
                u |= c & 0x3f;
                k--;
                if (k == 0) {
                    switch (n) {
                    case 1:
                        if (u < 0x80) return FALSE;
                        break;
                    case 2:
                        if (u < 0x800) return FALSE;
                        break;
                    case 3:
                        if (u < 0x10000 || u > 0x10ffff) return FALSE;
                        break;
                    default:
                        assert(((void)"unexpected control flow", 0));
                        return FALSE; /* never reached */
                    }
                    u = 0;
                    n = 0;
                }
            }
            else {
                return FALSE;
            }
            break;
        default:
            assert(((void)"unexpected control flow", 0));
            return FALSE; /* never reached */
        }
    }
    return (k == 0) ? TRUE : FALSE;
}

static bool_t unescape_string(char *str, bool_t cls) { /* cls: TRUE if used for character class matching */
    bool_t b = TRUE;
    size_t i, j;
    for (j = 0, i = 0; str[i]; i++) {
        if (str[i] == '\\') {
            i++;
            switch (str[i]) {
            case '\0': str[j++] = '\\'; str[j] = '\0'; return FALSE;
            case '\'': str[j++] = '\''; break;
            case '\"': str[j++] = '\"'; break;
            case '0': str[j++] = '\x00'; break;
            case 'a': str[j++] = '\x07'; break;
            case 'b': str[j++] = '\x08'; break;
            case 'f': str[j++] = '\x0c'; break;
            case 'n': str[j++] = '\x0a'; break;
            case 'r': str[j++] = '\x0d'; break;
            case 't': str[j++] = '\x09'; break;
            case 'v': str[j++] = '\x0b'; break;
            case 'x':
                {
                    char s = 0, c;
                    size_t k;
                    for (k = 0; k < 2; k++) {
                        char d;
                        c = str[i + k + 1];
                        d = (c >= '0' && c <= '9') ? c - '0' :
                            (c >= 'a' && c <= 'f') ? c - 'a' + 10 :
                            (c >= 'A' && c <= 'F') ? c - 'A' + 10 : -1;
                        if (d < 0) break;
                        s = (s << 4) | d;
                    }
                    if (k < 2) {
                        const size_t l = i + k;
                        str[j++] = '\\'; str[j++] = 'x';
                        while (i <= l) str[j++] = str[++i];
                        if (c == '\0') return FALSE;
                        b = FALSE;
                        continue;
                    }
                    str[j++] = s;
                    i += 2;
                }
                break;
            case 'u':
                {
                    int s = 0, t = 0;
                    char c;
                    size_t k;
                    for (k = 0; k < 4; k++) {
                        char d;
                        c = str[i + k + 1];
                        d = (c >= '0' && c <= '9') ? c - '0' :
                            (c >= 'a' && c <= 'f') ? c - 'a' + 10 :
                            (c >= 'A' && c <= 'F') ? c - 'A' + 10 : -1;
                        if (d < 0) break;
                        s = (s << 4) | d;
                    }
                    if (k < 4 || (s & 0xfc00) == 0xdc00) { /* invalid character or invalid surrogate code point */
                        const size_t l = i + k;
                        str[j++] = '\\'; str[j++] = 'u';
                        while (i <= l) str[j++] = str[++i];
                        if (c == '\0') return FALSE;
                        b = FALSE;
                        continue;
                    }
                    if ((s & 0xfc00) == 0xd800) { /* surrogate pair */
                        for (k = 4; k < 10; k++) {
                            c = str[i + k + 1];
                            if (k == 4) {
                                if (c != '\\') break;
                            }
                            else if (k == 5) {
                                if (c != 'u') break;
                            }
                            else {
                                const char d =
                                    (c >= '0' && c <= '9') ? c - '0' :
                                    (c >= 'a' && c <= 'f') ? c - 'a' + 10 :
                                    (c >= 'A' && c <= 'F') ? c - 'A' + 10 : -1;
                                if (d < 0) break;
                                t = (t << 4) | d;
                            }
                        }
                        if (k < 10 || (t & 0xfc00) != 0xdc00) { /* invalid character or invalid surrogate code point */
                            const size_t l = i + 4; /* NOTE: Not i + k to redo with recovery. */
                            str[j++] = '\\'; str[j++] = 'u';
                            while (i <= l) str[j++] = str[++i];
                            b = FALSE;
                            continue;
                        }
                    }
                    {
                        const int u = t ? ((((s & 0x03ff) + 0x0040) << 10) | (t & 0x03ff)) : s;
                        if (u < 0x0080) {
                            str[j++] = (char)u;
                        }
                        else if (u < 0x0800) {
                            str[j++] = (char)(0xc0 | (u >> 6));
                            str[j++] = (char)(0x80 | (u & 0x3f));
                        }
                        else if (u < 0x010000) {
                            str[j++] = (char)(0xe0 | (u >> 12));
                            str[j++] = (char)(0x80 | ((u >> 6) & 0x3f));
                            str[j++] = (char)(0x80 | (u & 0x3f));
                        }
                        else if (u < 0x110000) {
                            str[j++] = (char)(0xf0 | (u >> 18));
                            str[j++] = (char)(0x80 | ((u >> 12) & 0x3f));
                            str[j++] = (char)(0x80 | ((u >>  6) & 0x3f));
                            str[j++] = (char)(0x80 | (u & 0x3f));
                        }
                        else { /* never reached theoretically; in case */
                            const size_t l = i + 10;
                            str[j++] = '\\'; str[j++] = 'u';
                            while (i <= l) str[j++] = str[++i];
                            b = FALSE;
                            continue;
                        }
                    }
                    i += t ? 10 : 4;
                }
                break;
            case '\n': break;
            case '\r': if (str[i + 1] == '\n') i++; break;
            case '\\':
                if (cls) str[j++] = '\\'; /* left for character class matching (ex. considering [\^\]\\]) */
                str[j++] = '\\';
                break;
            default: str[j++] = '\\'; str[j++] = str[i];
            }
        }
        else {
            str[j++] = str[i];
        }
    }
    str[j] = '\0';
    return b;
}

static void remove_leading_blanks(char *str) {
    size_t i, j;
    for (i = 0; str[i]; i++) {
        if (
            str[i] != ' '  &&
            str[i] != '\v' &&
            str[i] != '\f' &&
            str[i] != '\t' &&
            str[i] != '\n' &&
            str[i] != '\r'
        ) break;
    }
    for (j = 0; str[i]; i++) {
        str[j++] = str[i];
    }
    str[j] = '\0';
}

static void remove_trailing_blanks(char *str) {
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
    str[j] = '\0';
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

static VALUE code_block_array__create_entry(VALUE array) {
    VALUE rcode = rb_funcall(cPackcr_CodeBlock, rb_intern("new"),0);
    rb_ary_push(array, rcode);
    return rcode;
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

static void node_const_array__copy(node_const_array_t *array, const node_const_array_t *src) {
    size_t i;
    node_const_array__clear(array);
    for (i = 0; i < src->len; i++) {
        node_const_array__add(array, src->buf[i]);
    }
}

static void node_const_array__term(node_const_array_t *array) {
    free((node_t **)array->buf);
}

static VALUE create_rule_node() {
    VALUE rnode = rb_funcall(cPackcr_Node, rb_intern("new"), 0);
    node_t *node;
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node->type = NODE_RULE;
    node->data.rule.name = NULL;
    node->data.rule.expr = NULL;
    node->data.rule.ref = 0;
    node_const_array__init(&node->data.rule.vars);
    node_const_array__init(&node->data.rule.capts);
    node->data.rule.line = VOID_VALUE;
    node->data.rule.col = VOID_VALUE;
    return rnode;
}

static VALUE create_action_node() {
    VALUE rnode = rb_funcall(cPackcr_Node, rb_intern("new"), 0);
    node_t *node;
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node->type = NODE_ACTION;
    code_block__init(&node->data.action.code);
    node->data.action.index = VOID_VALUE;
    node_const_array__init(&node->data.action.vars);
    node_const_array__init(&node->data.action.capts);
    return rnode;
}

static VALUE create_error_node() {
    VALUE rnode = rb_funcall(cPackcr_Node, rb_intern("new"), 0);
    node_t *node;
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    node->type = NODE_ERROR;
    node->data.error.expr = NULL;
    code_block__init(&node->data.error.code);
    node->data.error.index = VOID_VALUE;
    node_const_array__init(&node->data.error.vars);
    node_const_array__init(&node->data.error.capts);
    return rnode;
}

static node_t *create_node(node_type_t type) {
    node_t *const node = (node_t *)malloc_e(sizeof(node_t));
    node->type = type;
    switch (node->type) {
    case NODE_REFERENCE:
        node->data.reference.var = NULL;
        node->data.reference.index = VOID_VALUE;
        node->data.reference.name = NULL;
        node->data.reference.rule = NULL;
        node->data.reference.line = VOID_VALUE;
        node->data.reference.col = VOID_VALUE;
        break;
    case NODE_STRING:
        node->data.string.value = NULL;
        break;
    case NODE_CHARCLASS:
        node->data.charclass.value = NULL;
        break;
    case NODE_QUANTITY:
        node->data.quantity.min = node->data.quantity.max = 0;
        node->data.quantity.expr = NULL;
        break;
    case NODE_PREDICATE:
        node->data.predicate.neg = FALSE;
        node->data.predicate.expr = NULL;
        break;
    case NODE_SEQUENCE:
        node_array__init(&node->data.sequence.nodes);
        break;
    case NODE_ALTERNATE:
        node_array__init(&node->data.alternate.nodes);
        break;
    case NODE_CAPTURE:
        node->data.capture.expr = NULL;
        node->data.capture.index = VOID_VALUE;
        break;
    case NODE_EXPAND:
        node->data.expand.index = VOID_VALUE;
        node->data.expand.line = VOID_VALUE;
        node->data.expand.col = VOID_VALUE;
        break;
    default:
        print_error("Internal error [%d]\n", __LINE__);
        exit(-1);
    }
    return node;
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

static const node_t *lookup_rulehash(VALUE rctx, const char *name) {
    node_t *node;
    VALUE rname = rb_str_new2(name);
    VALUE rrulehash = rb_ivar_get(rctx, rb_intern("@rulehash"));
    VALUE rnode = rb_hash_aref(rrulehash, rname);
    if (rnode == Qnil) {
        return NULL;
    }
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    return node;
}

static void link_references(VALUE rctx, node_t *node) {
    if (node == NULL) return;
    switch (node->type) {
    case NODE_RULE:
        print_error("Internal error [%d]\n", __LINE__);
        exit(-1);
    case NODE_REFERENCE:
        node->data.reference.rule = lookup_rulehash(rctx, node->data.reference.name);
        if (node->data.reference.rule == NULL) {
            print_error("%s:" FMT_LU ":" FMT_LU ": No definition of rule '%s'\n",
                RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(node->data.reference.line + 1), (ulong_t)(node->data.reference.col + 1),
                node->data.reference.name);
            rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
        }
        else {
            assert(node->data.reference.rule->type == NODE_RULE);
            ((node_t *)node->data.reference.rule)->data.rule.ref++;
        }
        break;
    case NODE_STRING:
        break;
    case NODE_CHARCLASS:
        break;
    case NODE_QUANTITY:
        link_references(rctx, node->data.quantity.expr);
        break;
    case NODE_PREDICATE:
        link_references(rctx, node->data.predicate.expr);
        break;
    case NODE_SEQUENCE:
        {
            size_t i;
            for (i = 0; i < node->data.sequence.nodes.len; i++) {
                link_references(rctx, node->data.sequence.nodes.buf[i]);
            }
        }
        break;
    case NODE_ALTERNATE:
        {
            size_t i;
            for (i = 0; i < node->data.alternate.nodes.len; i++) {
                link_references(rctx, node->data.alternate.nodes.buf[i]);
            }
        }
        break;
    case NODE_CAPTURE:
        link_references(rctx, node->data.capture.expr);
        break;
    case NODE_EXPAND:
        break;
    case NODE_ACTION:
        break;
    case NODE_ERROR:
        link_references(rctx, node->data.error.expr);
        break;
    default:
        print_error("Internal error [%d]\n", __LINE__);
        exit(-1);
    }
}

static void verify_variables(VALUE rctx, node_t *node, node_const_array_t *vars) {
    node_const_array_t a;
    const bool_t b = (vars == NULL) ? TRUE : FALSE;
    if (node == NULL) return;
    if (b) {
        node_const_array__init(&a);
        vars = &a;
    }
    switch (node->type) {
    case NODE_RULE:
        print_error("Internal error [%d]\n", __LINE__);
        exit(-1);
    case NODE_REFERENCE:
        if (node->data.reference.index != VOID_VALUE) {
            size_t i;
            for (i = 0; i < vars->len; i++) {
                assert(vars->buf[i]->type == NODE_REFERENCE);
                if (node->data.reference.index == vars->buf[i]->data.reference.index) break;
            }
            if (i == vars->len) node_const_array__add(vars, node);
        }
        break;
    case NODE_STRING:
        break;
    case NODE_CHARCLASS:
        break;
    case NODE_QUANTITY:
        verify_variables(rctx, node->data.quantity.expr, vars);
        break;
    case NODE_PREDICATE:
        verify_variables(rctx, node->data.predicate.expr, vars);
        break;
    case NODE_SEQUENCE:
        {
            size_t i;
            for (i = 0; i < node->data.sequence.nodes.len; i++) {
                verify_variables(rctx, node->data.sequence.nodes.buf[i], vars);
            }
        }
        break;
    case NODE_ALTERNATE:
        {
            size_t i, j, k, m = vars->len;
            node_const_array_t v;
            node_const_array__init(&v);
            node_const_array__copy(&v, vars);
            for (i = 0; i < node->data.alternate.nodes.len; i++) {
                v.len = m;
                verify_variables(rctx, node->data.alternate.nodes.buf[i], &v);
                for (j = m; j < v.len; j++) {
                    for (k = m; k < vars->len; k++) {
                        if (v.buf[j]->data.reference.index == vars->buf[k]->data.reference.index) break;
                    }
                    if (k == vars->len) node_const_array__add(vars, v.buf[j]);
                }
            }
            node_const_array__term(&v);
        }
        break;
    case NODE_CAPTURE:
        verify_variables(rctx, node->data.capture.expr, vars);
        break;
    case NODE_EXPAND:
        break;
    case NODE_ACTION:
        node_const_array__copy(&node->data.action.vars, vars);
        break;
    case NODE_ERROR:
        node_const_array__copy(&node->data.error.vars, vars);
        verify_variables(rctx, node->data.error.expr, vars);
        break;
    default:
        print_error("Internal error [%d]\n", __LINE__);
        exit(-1);
    }
    if (b) {
        node_const_array__term(&a);
    }
}

static void verify_captures(VALUE rctx, node_t *node, node_const_array_t *capts) {
    node_const_array_t a;
    const bool_t b = (capts == NULL) ? TRUE : FALSE;
    if (node == NULL) return;
    if (b) {
        node_const_array__init(&a);
        capts = &a;
    }
    switch (node->type) {
    case NODE_RULE:
        print_error("Internal error [%d]\n", __LINE__);
        exit(-1);
    case NODE_REFERENCE:
        break;
    case NODE_STRING:
        break;
    case NODE_CHARCLASS:
        break;
    case NODE_QUANTITY:
        verify_captures(rctx, node->data.quantity.expr, capts);
        break;
    case NODE_PREDICATE:
        verify_captures(rctx, node->data.predicate.expr, capts);
        break;
    case NODE_SEQUENCE:
        {
            size_t i;
            for (i = 0; i < node->data.sequence.nodes.len; i++) {
                verify_captures(rctx, node->data.sequence.nodes.buf[i], capts);
            }
        }
        break;
    case NODE_ALTERNATE:
        {
            size_t i, j, m = capts->len;
            node_const_array_t v;
            node_const_array__init(&v);
            node_const_array__copy(&v, capts);
            for (i = 0; i < node->data.alternate.nodes.len; i++) {
                v.len = m;
                verify_captures(rctx, node->data.alternate.nodes.buf[i], &v);
                for (j = m; j < v.len; j++) {
                    node_const_array__add(capts, v.buf[j]);
                }
            }
            node_const_array__term(&v);
        }
        break;
    case NODE_CAPTURE:
        verify_captures(rctx, node->data.capture.expr, capts);
        node_const_array__add(capts, node);
        break;
    case NODE_EXPAND:
        {
            size_t i;
            for (i = 0; i < capts->len; i++) {
                assert(capts->buf[i]->type == NODE_CAPTURE);
                if (node->data.expand.index == capts->buf[i]->data.capture.index) break;
            }
            if (i >= capts->len && node->data.expand.index != VOID_VALUE) {
                print_error("%s:" FMT_LU ":" FMT_LU ": Capture " FMT_LU " not available at this position\n",
                    RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(node->data.expand.line + 1), (ulong_t)(node->data.expand.col + 1), (ulong_t)(node->data.expand.index + 1));
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
            }
        }
        break;
    case NODE_ACTION:
        node_const_array__copy(&node->data.action.capts, capts);
        break;
    case NODE_ERROR:
        node_const_array__copy(&node->data.error.capts, capts);
        verify_captures(rctx, node->data.error.expr, capts);
        break;
    default:
        print_error("Internal error [%d]\n", __LINE__);
        exit(-1);
    }
    if (b) {
        node_const_array__term(&a);
    }
}

static void dump_escaped_string(const char *str) {
    if (str == NULL) {
        fprintf(stdout, "null");
        return;
    }
    while (*str) {
        VALUE s = rb_funcall(cPackcr, rb_intern("escape_character"), 1, INT2NUM(*str++));
        fprintf(stdout, "%s", RSTRING_PTR(s));
    }
}

static void dump_integer_value(size_t value) {
    if (value == VOID_VALUE) {
        fprintf(stdout, "void");
    }
    else {
        fprintf(stdout, FMT_LU, (ulong_t)value);
    }
}

static void dump_node(VALUE rctx, VALUE rnode, const int indent) {
    node_t *node;
    TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
    if (node == NULL) return;
    switch (node->type) {
    case NODE_RULE:
        {
            VALUE rcodes = rb_ivar_get(rnode, rb_intern("@codes"));
            fprintf(stdout, "%*sRule(name:'%s', ref:%d, vars.len:" FMT_LU ", capts.len:" FMT_LU ", codes.len:" FMT_LU ") {\n",
                indent, "", node->data.rule.name, node->data.rule.ref,
                (ulong_t)node->data.rule.vars.len, (ulong_t)node->data.rule.capts.len, NIL_P(rcodes) ? 0 : (ulong_t) NUM2SIZET(rb_funcall(rcodes, rb_intern("length"), 0)));
        }
        {
            VALUE rexpr = TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, node->data.rule.expr);
            dump_node(rctx, rexpr, indent + 2);
        }
        fprintf(stdout, "%*s}\n", indent, "");
        break;
    case NODE_REFERENCE:
        fprintf(stdout, "%*sReference(var:'%s', index:", indent, "", node->data.reference.var);
        dump_integer_value(node->data.reference.index);
        fprintf(stdout, ", name:'%s', rule:'%s')\n", node->data.reference.name,
            (node->data.reference.rule) ? node->data.reference.rule->data.rule.name : NULL);
        break;
    case NODE_STRING:
        fprintf(stdout, "%*sString(value:'", indent, "");
        dump_escaped_string(node->data.string.value);
        fprintf(stdout, "')\n");
        break;
    case NODE_CHARCLASS:
        fprintf(stdout, "%*sCharclass(value:'", indent, "");
        dump_escaped_string(node->data.charclass.value);
        fprintf(stdout, "')\n");
        break;
    case NODE_QUANTITY:
        fprintf(stdout, "%*sQuantity(min:%d, max:%d) {\n", indent, "", node->data.quantity.min, node->data.quantity.max);
        {
            VALUE rexpr = TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, node->data.quantity.expr);
            dump_node(rctx, rexpr, indent + 2);
        }
        fprintf(stdout, "%*s}\n", indent, "");
        break;
    case NODE_PREDICATE:
        fprintf(stdout, "%*sPredicate(neg:%d) {\n", indent, "", node->data.predicate.neg);
        {
            VALUE rexpr = TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, node->data.predicate.expr);
            dump_node(rctx, rexpr, indent + 2);
        }
        fprintf(stdout, "%*s}\n", indent, "");
        break;
    case NODE_SEQUENCE:
        fprintf(stdout, "%*sSequence(max:" FMT_LU ", len:" FMT_LU ") {\n",
            indent, "", (ulong_t)node->data.sequence.nodes.max, (ulong_t)node->data.sequence.nodes.len);
        {
            size_t i;
            for (i = 0; i < node->data.sequence.nodes.len; i++) {
                VALUE rnode = TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, node->data.sequence.nodes.buf[i]);
                dump_node(rctx, rnode, indent + 2);
            }
        }
        fprintf(stdout, "%*s}\n", indent, "");
        break;
    case NODE_ALTERNATE:
        fprintf(stdout, "%*sAlternate(max:" FMT_LU ", len:" FMT_LU ") {\n",
            indent, "", (ulong_t)node->data.alternate.nodes.max, (ulong_t)node->data.alternate.nodes.len);
        {
            size_t i;
            for (i = 0; i < node->data.alternate.nodes.len; i++) {
                VALUE rnode = TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, node->data.alternate.nodes.buf[i]);
                dump_node(rctx, rnode, indent + 2);
            }
        }
        fprintf(stdout, "%*s}\n", indent, "");
        break;
    case NODE_CAPTURE:
        fprintf(stdout, "%*sCapture(index:", indent, "");
        dump_integer_value(node->data.capture.index);
        fprintf(stdout, ") {\n");
        {
            VALUE rexpr = TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, node->data.capture.expr);
            dump_node(rctx, rexpr, indent + 2);
        }
        fprintf(stdout, "%*s}\n", indent, "");
        break;
    case NODE_EXPAND:
        fprintf(stdout, "%*sExpand(index:", indent, "");
        dump_integer_value(node->data.expand.index);
        fprintf(stdout, ")\n");
        break;
    case NODE_ACTION:
        fprintf(stdout, "%*sAction(index:", indent, "");
        dump_integer_value(node->data.action.index);
        fprintf(stdout, ", code:{");
        dump_escaped_string(node->data.action.code.text);
        fprintf(stdout, "}, vars:");
        if (node->data.action.vars.len + node->data.action.capts.len > 0) {
            size_t i;
            fprintf(stdout, "\n");
            for (i = 0; i < node->data.action.vars.len; i++) {
                fprintf(stdout, "%*s'%s'\n", indent + 2, "", node->data.action.vars.buf[i]->data.reference.var);
            }
            for (i = 0; i < node->data.action.capts.len; i++) {
                fprintf(stdout, "%*s$" FMT_LU "\n", indent + 2, "", (ulong_t)(node->data.action.capts.buf[i]->data.capture.index + 1));
            }
            fprintf(stdout, "%*s)\n", indent, "");
        }
        else {
            fprintf(stdout, "none)\n");
        }
        break;
    case NODE_ERROR:
        fprintf(stdout, "%*sError(index:", indent, "");
        dump_integer_value(node->data.error.index);
        fprintf(stdout, ", code:{");
        dump_escaped_string(node->data.error.code.text);
        fprintf(stdout, "}, vars:\n");
        {
            size_t i;
            for (i = 0; i < node->data.error.vars.len; i++) {
                fprintf(stdout, "%*s'%s'\n", indent + 2, "", node->data.error.vars.buf[i]->data.reference.var);
            }
            for (i = 0; i < node->data.error.capts.len; i++) {
                fprintf(stdout, "%*s$" FMT_LU "\n", indent + 2, "", (ulong_t)(node->data.error.capts.buf[i]->data.capture.index + 1));
            }
        }
        fprintf(stdout, "%*s) {\n", indent, "");
        {
            VALUE rexpr = TypedData_Wrap_Struct(cPackcr_Node, &packcr_ptr_data_type, node->data.error.expr);
            dump_node(rctx, rexpr, indent + 2);
        }
        fprintf(stdout, "%*s}\n", indent, "");
        break;
    default:
        print_error("%*sInternal error [%d]\n", indent, "", __LINE__);
        exit(-1);
    }
}

static bool_t match_directive_c(VALUE rctx) {
    return RB_TEST(rb_funcall(rctx, rb_intern("match_section_line_continuable_"), 1, rb_str_new_cstr("#")));
}

static bool_t match_comment(VALUE rctx) {
    return RB_TEST(rb_funcall(rctx, rb_intern("match_section_line_"), 1, rb_str_new_cstr("#")));
}

static bool_t match_comment_c(VALUE rctx) {
    return RB_TEST(rb_funcall(rctx, rb_intern("match_section_block_"), 3, rb_str_new_cstr("/*"), rb_str_new_cstr("*/"), rb_str_new_cstr("C comment")));
}

static bool_t match_comment_cxx(VALUE rctx) {
    return RB_TEST(rb_funcall(rctx, rb_intern("match_section_line_"), 1, rb_str_new_cstr("//")));
}

static bool_t match_quotation_single(VALUE rctx) {
    return rb_funcall(rctx, rb_intern("match_quotation_"), 3, rb_str_new_cstr("\'"), rb_str_new_cstr("\'"), rb_str_new_cstr("single quotation"));
}

static bool_t match_quotation_double(VALUE rctx) {
    return rb_funcall(rctx, rb_intern("match_quotation_"), 3, rb_str_new_cstr("\""), rb_str_new_cstr("\""), rb_str_new_cstr("double quotation"));
}

static bool_t match_character_class(VALUE rctx) {
    return rb_funcall(rctx, rb_intern("match_quotation_"), 3, rb_str_new_cstr("["), rb_str_new_cstr("]"), rb_str_new_cstr("character class"));
}

static bool_t match_spaces(VALUE rctx) {
    size_t n = 0;
    while (RB_TEST(rb_funcall(rctx, rb_intern("match_blank"), 0)) || RB_TEST(rb_funcall(rctx, rb_intern("eol?"), 0)) || match_comment(rctx)) n++;
    return (n > 0) ? TRUE : FALSE;
}

static bool_t match_number(VALUE rctx) {
    if (RB_TEST(rb_funcall(rctx, rb_intern("match_character_range"), 2, INT2NUM('0'), INT2NUM('9')))) {
        while (RB_TEST(rb_funcall(rctx, rb_intern("match_character_range"), 2, INT2NUM('0'), INT2NUM('9'))));
        return TRUE;
    }
    return FALSE;
}

static bool_t match_identifier(VALUE rctx) {
    if (
        RB_TEST(rb_funcall(rctx, rb_intern("match_character_range"), 2, INT2NUM('a'), INT2NUM('z'))) ||
        RB_TEST(rb_funcall(rctx, rb_intern("match_character_range"), 2, INT2NUM('A'), INT2NUM('Z'))) ||
        RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('_')))
    ) {
        while (
            RB_TEST(rb_funcall(rctx, rb_intern("match_character_range"), 2, INT2NUM('a'), INT2NUM('z'))) ||
            RB_TEST(rb_funcall(rctx, rb_intern("match_character_range"), 2, INT2NUM('A'), INT2NUM('Z'))) ||
            RB_TEST(rb_funcall(rctx, rb_intern("match_character_range"), 2, INT2NUM('0'), INT2NUM('9'))) ||
            RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('_')))
        );
        return TRUE;
    }
    return FALSE;
}

static bool_t match_code_block(VALUE rctx) {
    const size_t l = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
    const size_t m = NUM2SIZET(rb_funcall(rctx, rb_intern("column_number"), 0));
    if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('{')))) {
        int d = 1;
        for (;;) {
            if (RB_TEST(rb_funcall(rctx, rb_intern("eof?"), 0))) {
                print_error("%s:" FMT_LU ":" FMT_LU ": Premature EOF in code block\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1));
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
                break;
            }
            if (
                match_directive_c(rctx) ||
                match_comment_c(rctx) ||
                match_comment_cxx(rctx) ||
                match_quotation_single(rctx) ||
                match_quotation_double(rctx)
            ) continue;
            if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('{')))) {
                d++;
            }
            else if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('}')))) {
                d--;
                if (d == 0) break;
            }
            else {
                if (!RB_TEST(rb_funcall(rctx, rb_intern("eol?"), 0))) {
                    VALUE rbuffer = rb_ivar_get(rctx, rb_intern("@buffer"));
                    if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('$')))) {
                        rb_funcall(rbuffer, rb_intern("[]="), 2, rb_funcall(rb_ivar_get(rctx, rb_intern("@bufcur")), rb_intern("pred"), 0), SIZET2NUM('_'));
                    }
                    else {
                        RB_TEST(rb_funcall(rctx, rb_intern("match_character_any"), 0));
                    }
                }
            }
        }
        return TRUE;
    }
    return FALSE;
}

static bool_t match_footer_start(VALUE rctx) {
    return RB_TEST(rb_funcall(rctx, rb_intern("match_string"), 1, rb_str_new_cstr("%%")));
}

static node_t *parse_expression(VALUE rctx, VALUE rrule);

static node_t *parse_primary(VALUE rctx, VALUE rrule) {
    const size_t p = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
    const size_t l = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
    const size_t m = NUM2SIZET(rb_funcall(rctx, rb_intern("column_number"), 0));
    const size_t n = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@charnum")));
    const size_t o = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linepos")));
    node_t *rule;
    node_t *n_p = NULL;
    VALUE rbuffer = rb_ivar_get(rctx, rb_intern("@buffer"));
    TypedData_Get_Struct(rrule, node_t, &packcr_ptr_data_type, rule);
    if (match_identifier(rctx)) {
        const size_t q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
        size_t r = VOID_VALUE, s = VOID_VALUE;
        match_spaces(rctx);
        if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM(':')))) {
            match_spaces(rctx);
            r = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
            if (!match_identifier(rctx)) goto EXCEPTION;
            s = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
            match_spaces(rctx);
        }
        if (RB_TEST(rb_funcall(rctx, rb_intern("match_string"), 1, rb_str_new_cstr("<-")))) goto EXCEPTION;
        n_p = create_node(NODE_REFERENCE);
        if (r == VOID_VALUE) {
            VALUE rname = rb_funcall(rbuffer, rb_intern("to_s"), 0);
            char *name;
            rname = rb_funcall(rname, rb_intern("[]"), 2, SIZET2NUM(p), SIZET2NUM(q - p));
            name = StringValuePtr(rname);
            assert(q >= p);
            n_p->data.reference.var = NULL;
            n_p->data.reference.index = VOID_VALUE;
            n_p->data.reference.name = strndup_e(name, strlen(name));
        }
        else {
            VALUE rvar = rb_funcall(rbuffer, rb_intern("to_s"), 0);
            char *var;
            rvar = rb_funcall(rvar, rb_intern("[]"), 2, SIZET2NUM(p), SIZET2NUM(q - p));
            var = StringValuePtr(rvar);
            assert(s != VOID_VALUE); /* s should have a valid value when r has a valid value */
            assert(q >= p);
            n_p->data.reference.var = strndup_e(var, strlen(var));
            if (n_p->data.reference.var[0] == '_') {
                print_error("%s:" FMT_LU ":" FMT_LU ": Leading underscore in variable name '%s'\n",
                    RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1), n_p->data.reference.var);
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
            }
            {
                size_t i;
                for (i = 0; i < rule->data.rule.vars.len; i++) {
                    assert(rule->data.rule.vars.buf[i]->type == NODE_REFERENCE);
                    if (strcmp(n_p->data.reference.var, rule->data.rule.vars.buf[i]->data.reference.var) == 0) break;
                }
                if (i == rule->data.rule.vars.len) node_const_array__add(&rule->data.rule.vars, n_p);
                n_p->data.reference.index = i;
            }
            assert(s >= r);
            {
                VALUE rname = rb_funcall(rbuffer, rb_intern("to_s"), 0);
                char *name;
                rname = rb_funcall(rname, rb_intern("[]"), 2, SIZET2NUM(r), SIZET2NUM(s - r));
                name = StringValuePtr(rname);
                n_p->data.reference.name = strndup_e(name, strlen(name));
            }
        }
        n_p->data.reference.line = l;
        n_p->data.reference.col = m;
    }
    else if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('(')))) {
        match_spaces(rctx);
        n_p = parse_expression(rctx, rrule);
        if (n_p == NULL) goto EXCEPTION;
        if (!RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM(')')))) goto EXCEPTION;
        match_spaces(rctx);
    }
    else if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('<')))) {
        match_spaces(rctx);
        n_p = create_node(NODE_CAPTURE);
        n_p->data.capture.index = rule->data.rule.capts.len;
        node_const_array__add(&rule->data.rule.capts, n_p);
        n_p->data.capture.expr = parse_expression(rctx, rrule);
        if (n_p->data.capture.expr == NULL || !RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('>')))) {
            rule->data.rule.capts.len = n_p->data.capture.index;
            goto EXCEPTION;
        }
        match_spaces(rctx);
    }
    else if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('$')))) {
        size_t p;
        match_spaces(rctx);
        p = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
        if (match_number(rctx)) {
            const size_t q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
            char *s;
            VALUE rs = rb_funcall(rbuffer, rb_intern("to_s"), 0);
            rs = rb_funcall(rs, rb_intern("[]"), 2, SIZET2NUM(p), SIZET2NUM(q - p));
            s = StringValuePtr(rs);
            match_spaces(rctx);
            n_p = create_node(NODE_EXPAND);
            assert(q >= p);
            s = strndup_e(s, strlen(s));
            n_p->data.expand.index = string_to_size_t(s);
            if (n_p->data.expand.index == VOID_VALUE) {
                print_error("%s:" FMT_LU ":" FMT_LU ": Invalid unsigned number '%s'\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1), s);
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
            }
            else if (n_p->data.expand.index == 0) {
                print_error("%s:" FMT_LU ":" FMT_LU ": 0 not allowed\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1));
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
            }
            else if (s[0] == '0') {
                print_error("%s:" FMT_LU ":" FMT_LU ": 0-prefixed number not allowed\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1));
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
                n_p->data.expand.index = 0;
            }
            free(s);
            if (n_p->data.expand.index > 0 && n_p->data.expand.index != VOID_VALUE) {
                n_p->data.expand.index--;
                n_p->data.expand.line = l;
                n_p->data.expand.col = m;
            }
        }
        else {
            goto EXCEPTION;
        }
    }
    else if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('.')))) {
        match_spaces(rctx);
        n_p = create_node(NODE_CHARCLASS);
        n_p->data.charclass.value = NULL;
        if (!RB_TEST(rb_ivar_get(rctx, rb_intern("@ascii")))) {
            rb_ivar_set(rctx, rb_intern("@utf8"), Qtrue);
        }
    }
    else if (match_character_class(rctx)) {
        const size_t q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
        char *charclass;
        VALUE rcharclass = rb_funcall(rbuffer, rb_intern("to_s"), 0);
        rcharclass = rb_funcall(rcharclass, rb_intern("[]"), 2, SIZET2NUM(p + 1), SIZET2NUM(q - p - 2));
        charclass = StringValuePtr(rcharclass);
        match_spaces(rctx);
        n_p = create_node(NODE_CHARCLASS);
        n_p->data.charclass.value = strndup_e(charclass, strlen(charclass));
        if (!unescape_string(n_p->data.charclass.value, TRUE)) {
            print_error("%s:" FMT_LU ":" FMT_LU ": Illegal escape sequence\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1));
            rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
        }
        if (!RB_TEST(rb_ivar_get(rctx, rb_intern("@ascii"))) && !is_valid_utf8_string(n_p->data.charclass.value)) {
            print_error("%s:" FMT_LU ":" FMT_LU ": Invalid UTF-8 string\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1));
            rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
        }
        if (!RB_TEST(rb_ivar_get(rctx, rb_intern("@ascii"))) && n_p->data.charclass.value[0] != '\0') {
            rb_ivar_set(rctx, rb_intern("@utf8"), Qtrue);
        }
    }
    else if (match_quotation_single(rctx) || match_quotation_double(rctx)) {
        const size_t q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
        char *string;
        VALUE rstring = rb_funcall(rbuffer, rb_intern("to_s"), 0);
        rstring = rb_funcall(rstring, rb_intern("[]"), 2, SIZET2NUM(p + 1), SIZET2NUM(q - p - 2));
        string = StringValuePtr(rstring);
        match_spaces(rctx);
        n_p = create_node(NODE_STRING);
        n_p->data.string.value = strndup_e(string, strlen(string));
        if (!unescape_string(n_p->data.string.value, FALSE)) {
            print_error("%s:" FMT_LU ":" FMT_LU ": Illegal escape sequence\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1));
            rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
        }
        if (!RB_TEST(rb_ivar_get(rctx, rb_intern("@ascii"))) && !is_valid_utf8_string(n_p->data.string.value)) {
            print_error("%s:" FMT_LU ":" FMT_LU ": Invalid UTF-8 string\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1));
            rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
        }
    }
    else if (match_code_block(rctx)) {
        const size_t q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
        VALUE rn_p, rcodes;
        char *text;
        VALUE rtext = rb_funcall(rbuffer, rb_intern("to_s"), 0);
        rtext = rb_funcall(rtext, rb_intern("[]"), 2, SIZET2NUM(p + 1), SIZET2NUM(q - p - 2));
        text = StringValuePtr(rtext);
        rcodes = rb_ivar_get(rrule, rb_intern("@codes"));
        match_spaces(rctx);
        rn_p = create_action_node();
        TypedData_Get_Struct(rn_p, node_t, &packcr_ptr_data_type, n_p);
        n_p->data.action.code.text = strndup_e(text, strlen(text));
        n_p->data.action.code.len = find_trailing_blanks(n_p->data.action.code.text);
        n_p->data.action.code.line = l;
        n_p->data.action.code.col = m;
        n_p->data.action.index = NUM2SIZET(rb_funcall(rcodes, rb_intern("length"), 0));
        rb_ary_push(rcodes, rn_p);
    }
    else {
        goto EXCEPTION;
    }
    return n_p;

EXCEPTION:;
    destroy_node(n_p);
    rb_ivar_set(rctx, rb_intern("@bufcur"), SIZET2NUM(p));
    rb_ivar_set(rctx, rb_intern("@linenum"), SIZET2NUM(l));
    rb_ivar_set(rctx, rb_intern("@charnum"), SIZET2NUM(n));
    rb_ivar_set(rctx, rb_intern("@linepos"), SIZET2NUM(o));
    return NULL;
}

static node_t *parse_term(VALUE rctx, VALUE rrule) {
    const size_t p = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
    const size_t l = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
    const size_t n = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@charnum")));
    const size_t o = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linepos")));
    node_t *n_p = NULL;
    node_t *n_q = NULL;
    node_t *n_r = NULL;
    node_t *n_t = NULL;
    const char t = RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('&'))) ? '&' : RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('!'))) ? '!' : '\0';
    VALUE rbuffer = rb_ivar_get(rctx, rb_intern("@buffer"));
    if (t) match_spaces(rctx);
    n_p = parse_primary(rctx, rrule);
    if (n_p == NULL) goto EXCEPTION;
    if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('*')))) {
        match_spaces(rctx);
        n_q = create_node(NODE_QUANTITY);
        n_q->data.quantity.min = 0;
        n_q->data.quantity.max = -1;
        n_q->data.quantity.expr = n_p;
    }
    else if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('+')))) {
        match_spaces(rctx);
        n_q = create_node(NODE_QUANTITY);
        n_q->data.quantity.min = 1;
        n_q->data.quantity.max = -1;
        n_q->data.quantity.expr = n_p;
    }
    else if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('?')))) {
        match_spaces(rctx);
        n_q = create_node(NODE_QUANTITY);
        n_q->data.quantity.min = 0;
        n_q->data.quantity.max = 1;
        n_q->data.quantity.expr = n_p;
    }
    else {
        n_q = n_p;
    }
    switch (t) {
    case '&':
        n_r = create_node(NODE_PREDICATE);
        n_r->data.predicate.neg = FALSE;
        n_r->data.predicate.expr = n_q;
        break;
    case '!':
        n_r = create_node(NODE_PREDICATE);
        n_r->data.predicate.neg = TRUE;
        n_r->data.predicate.expr = n_q;
        break;
    default:
        n_r = n_q;
    }
    if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('~')))) {
        size_t p, l, m;
        match_spaces(rctx);
        p = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
        l = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
        m = NUM2SIZET(rb_funcall(rctx, rb_intern("column_number"), 0));
        if (match_code_block(rctx)) {
            const size_t q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
            VALUE rcodes = rb_ivar_get(rrule, rb_intern("@codes"));
            VALUE rn_t;
            char *text;
            VALUE rtext = rb_funcall(rbuffer, rb_intern("to_s"), 0);
            rtext = rb_funcall(rtext, rb_intern("[]"), 2, SIZET2NUM(p + 1), SIZET2NUM(q - p - 2));
            text = StringValuePtr(rtext);
            match_spaces(rctx);
            rn_t = create_error_node();
            TypedData_Get_Struct(rn_t, node_t, &packcr_ptr_data_type, n_t);
            n_t->data.error.expr = n_r;
            n_t->data.error.code.text = strndup_e(text, strlen(text));
            n_t->data.error.code.len = find_trailing_blanks(n_t->data.error.code.text);
            n_t->data.error.code.line = l;
            n_t->data.error.code.col = m;
            n_t->data.error.index = NUM2SIZET(rb_funcall(rcodes, rb_intern("length"), 0));
            rb_ary_push(rcodes, rn_t);
        }
        else {
            goto EXCEPTION;
        }
    }
    else {
        n_t = n_r;
    }
    return n_t;

EXCEPTION:;
    destroy_node(n_r);
    rb_ivar_set(rctx, rb_intern("@bufcur"), SIZET2NUM(p));
    rb_ivar_set(rctx, rb_intern("@linenum"), SIZET2NUM(l));
    rb_ivar_set(rctx, rb_intern("@charnum"), SIZET2NUM(n));
    rb_ivar_set(rctx, rb_intern("@linepos"), SIZET2NUM(o));
    return NULL;
}

static node_t *parse_sequence(VALUE rctx, VALUE rrule) {
    const size_t p = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
    const size_t l = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
    const size_t n = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@charnum")));
    const size_t o = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linepos")));
    node_array_t *a_t = NULL;
    node_t *n_t = NULL;
    node_t *n_u = NULL;
    node_t *n_s = NULL;
    n_t = parse_term(rctx, rrule);
    if (n_t == NULL) goto EXCEPTION;
    n_u = parse_term(rctx, rrule);
    if (n_u != NULL) {
        n_s = create_node(NODE_SEQUENCE);
        a_t = &n_s->data.sequence.nodes;
        node_array__add(a_t, n_t);
        node_array__add(a_t, n_u);
        while ((n_t = parse_term(rctx, rrule)) != NULL) {
            node_array__add(a_t, n_t);
        }
    }
    else {
        n_s = n_t;
    }
    return n_s;

EXCEPTION:;
    rb_ivar_set(rctx, rb_intern("@bufcur"), SIZET2NUM(p));
    rb_ivar_set(rctx, rb_intern("@linenum"), SIZET2NUM(l));
    rb_ivar_set(rctx, rb_intern("@charnum"), SIZET2NUM(n));
    rb_ivar_set(rctx, rb_intern("@linepos"), SIZET2NUM(o));
    return NULL;
}

static node_t *parse_expression(VALUE rctx, VALUE rrule) {
    const size_t p = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
    const size_t l = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
    const size_t n = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@charnum")));
    const size_t o = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linepos")));
    size_t q;
    node_array_t *a_s = NULL;
    node_t *n_s = NULL;
    node_t *n_e = NULL;
    n_s = parse_sequence(rctx, rrule);
    if (n_s == NULL) goto EXCEPTION;
    q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
    if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('/')))) {
        rb_ivar_set(rctx, rb_intern("@bufcur"), SIZET2NUM(q));
        n_e = create_node(NODE_ALTERNATE);
        a_s = &n_e->data.alternate.nodes;
        node_array__add(a_s, n_s);
        while (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('/')))) {
            match_spaces(rctx);
            n_s = parse_sequence(rctx, rrule);
            if (n_s == NULL) goto EXCEPTION;
            node_array__add(a_s, n_s);
        }
    }
    else {
        n_e = n_s;
    }
    return n_e;

EXCEPTION:;
    destroy_node(n_e);
    rb_ivar_set(rctx, rb_intern("@bufcur"), SIZET2NUM(p));
    rb_ivar_set(rctx, rb_intern("@linenum"), SIZET2NUM(l));
    rb_ivar_set(rctx, rb_intern("@charnum"), SIZET2NUM(n));
    rb_ivar_set(rctx, rb_intern("@linepos"), SIZET2NUM(o));
    return NULL;
}

static VALUE parse_rule(VALUE rctx) {
    const size_t p = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
    const size_t l = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
    const size_t m = NUM2SIZET(rb_funcall(rctx, rb_intern("column_number"), 0));
    const size_t n = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@charnum")));
    const size_t o = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linepos")));
    size_t q;
    node_t *n_r = NULL;
    VALUE rbuffer = rb_ivar_get(rctx, rb_intern("@buffer"));
    VALUE rn_r;
    char *name;
    VALUE rname;
    if (!match_identifier(rctx)) goto EXCEPTION;
    q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
    match_spaces(rctx);
    if (!RB_TEST(rb_funcall(rctx, rb_intern("match_string"), 1, rb_str_new_cstr("<-")))) goto EXCEPTION;
    match_spaces(rctx);
    rn_r = create_rule_node();
    TypedData_Get_Struct(rn_r, node_t, &packcr_ptr_data_type, n_r);
    n_r->data.rule.expr = parse_expression(rctx, rn_r);
    if (n_r->data.rule.expr == NULL) goto EXCEPTION;
    assert(q >= p);
    rname = rb_funcall(rbuffer, rb_intern("to_s"), 0);
    rname = rb_funcall(rname, rb_intern("[]"), 2, SIZET2NUM(p), SIZET2NUM(q - p));
    name = StringValuePtr(rname);
    n_r->data.rule.name = strndup_e(name, strlen(name));
    n_r->data.rule.line = l;
    n_r->data.rule.col = m;
    return rn_r;

EXCEPTION:;
    destroy_node(n_r);
    rb_ivar_set(rctx, rb_intern("@bufcur"), SIZET2NUM(p));
    rb_ivar_set(rctx, rb_intern("@linenum"), SIZET2NUM(l));
    rb_ivar_set(rctx, rb_intern("@charnum"), SIZET2NUM(n));
    rb_ivar_set(rctx, rb_intern("@linepos"), SIZET2NUM(o));
    return Qnil;
}

static void dump_options(VALUE rctx) {
    fprintf(stdout, "value_type: '%s'\n", RSTRING_PTR(rb_funcall(rctx, rb_intern("value_type"), 0)));
    fprintf(stdout, "auxil_type: '%s'\n", RSTRING_PTR(rb_funcall(rctx, rb_intern("auxil_type"), 0)));
    fprintf(stdout, "prefix: '%s'\n", RSTRING_PTR(rb_funcall(rctx, rb_intern("prefix"), 0)));
}

static bool_t parse_directive_include_(VALUE rctx, const char *name, VALUE output1, VALUE output2) {
    VALUE rbuffer = rb_ivar_get(rctx, rb_intern("@buffer"));
    if (!RB_TEST(rb_funcall(rctx, rb_intern("match_string"), 1, rb_str_new_cstr(name)))) return FALSE;
    match_spaces(rctx);
    {
        const size_t p = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
        const size_t l = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
        const size_t m = NUM2SIZET(rb_funcall(rctx, rb_intern("column_number"), 0));
        if (match_code_block(rctx)) {
            const size_t q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
            match_spaces(rctx);
            if (output1 != Qnil) {
                code_block_t *c;
                VALUE rc = code_block_array__create_entry(output1);
                TypedData_Get_Struct(rc, code_block_t, &packcr_ptr_data_type, c);
                char *text;
                VALUE rtext = rb_funcall(rbuffer, rb_intern("to_s"), 0);
                rtext = rb_funcall(rtext, rb_intern("[]"), 2, SIZET2NUM(p + 1), SIZET2NUM(q - p - 2));
                text = StringValuePtr(rtext);
                c->text = strndup_e(text, strlen(text));
                c->len = q - p - 2;
                c->line = l;
                c->col = m;
            }
            if (output2 != Qnil) {
                code_block_t *c;
                VALUE rc = code_block_array__create_entry(output2);
                TypedData_Get_Struct(rc, code_block_t, &packcr_ptr_data_type, c);
                char *text;
                VALUE rtext = rb_funcall(rbuffer, rb_intern("to_s"), 0);
                rtext = rb_funcall(rtext, rb_intern("[]"), 2, SIZET2NUM(p + 1), SIZET2NUM(q - p - 2));
                text = StringValuePtr(rtext);
                c->text = strndup_e(text, strlen(text));
                c->len = q - p - 2;
                c->line = l;
                c->col = m;
            }
        }
        else {
            print_error("%s:" FMT_LU ":" FMT_LU ": Illegal %s syntax\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1), name);
            rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
        }
    }
    return TRUE;
}

static bool_t parse_directive_string_(VALUE rctx, const char *name, const char *varname, string_flag_t mode) {
    const size_t l = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
    const size_t m = NUM2SIZET(rb_funcall(rctx, rb_intern("column_number"), 0));
    if (!RB_TEST(rb_funcall(rctx, rb_intern("match_string"), 1, rb_str_new_cstr(name)))) return FALSE;
    match_spaces(rctx);
    {
        char *s = NULL;
        const size_t p = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
        const size_t lv = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
        const size_t mv = NUM2SIZET(rb_funcall(rctx, rb_intern("column_number"), 0));
        size_t q;
        VALUE rbuffer = rb_ivar_get(rctx, rb_intern("@buffer"));
        if (match_quotation_single(rctx) || match_quotation_double(rctx)) {
            q = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@bufcur")));
            match_spaces(rctx);
            {
                VALUE rs = rb_funcall(rbuffer, rb_intern("to_s"), 0);
                rs = rb_funcall(rs, rb_intern("[]"), 2, SIZET2NUM(p + 1), SIZET2NUM(q - p - 2));
                s = StringValuePtr(rs);
                s = strndup_e(s, strlen(s));
            }
            if (!unescape_string(s, FALSE)) {
                print_error("%s:" FMT_LU ":" FMT_LU ": Illegal escape sequence\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(lv + 1), (ulong_t)(mv + 1));
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
            }
        }
        else {
            print_error("%s:" FMT_LU ":" FMT_LU ": Illegal %s syntax\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1), name);
            rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
        }
        if (s != NULL) {
            string_flag_t f = STRING_FLAG__NONE;
            bool_t b = TRUE;
            remove_leading_blanks(s);
            remove_trailing_blanks(s);
            assert((mode & ~7) == 0);
            if ((mode & STRING_FLAG__NOTEMPTY) && !is_filled_string(s)) {
                print_error("%s:" FMT_LU ":" FMT_LU ": Empty string\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(lv + 1), (ulong_t)(mv + 1));
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
                f |= STRING_FLAG__NOTEMPTY;
            }
            if ((mode & STRING_FLAG__NOTVOID) && strcmp(s, "void") == 0) {
                print_error("%s:" FMT_LU ":" FMT_LU ": 'void' not allowed\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(lv + 1), (ulong_t)(mv + 1));
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
                f |= STRING_FLAG__NOTVOID;
            }
            if ((mode & STRING_FLAG__IDENTIFIER) && !is_identifier_string(s)) {
                if (!(f & STRING_FLAG__NOTEMPTY)) {
                    print_error("%s:" FMT_LU ":" FMT_LU ": Invalid identifier\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(lv + 1), (ulong_t)(mv + 1));
                    rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
                }
                f |= STRING_FLAG__IDENTIFIER;
            }
            if (rb_ivar_get(rctx, rb_intern(varname)) != Qnil) {
                print_error("%s:" FMT_LU ":" FMT_LU ": Multiple %s definition\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1), name);
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
                b = FALSE;
            }
            if (f == STRING_FLAG__NONE && b) {
                rb_ivar_set(rctx, rb_intern(varname), rb_str_new2(s));
            }
            else {
                free(s); s = NULL;
            }
        }
    }
    return TRUE;
}

static bool_t parse(VALUE rctx) {
    {
        bool_t b = TRUE;
        match_spaces(rctx);
        for (;;) {
            size_t l, m, n, o;
            if (RB_TEST(rb_funcall(rctx, rb_intern("eof?"), 0)) || match_footer_start(rctx)) break;
            l = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linenum")));
            m = NUM2SIZET(rb_funcall(rctx, rb_intern("column_number"), 0));
            n = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@charnum")));
            o = NUM2SIZET(rb_ivar_get(rctx, rb_intern("@linepos")));
            if (
                parse_directive_include_(rctx, "%earlysource", rb_ivar_get(rctx, rb_intern("@esource")), Qnil) ||
                parse_directive_include_(rctx, "%earlyheader", rb_ivar_get(rctx, rb_intern("@eheader")), Qnil) ||
                parse_directive_include_(rctx, "%earlycommon", rb_ivar_get(rctx, rb_intern("@esource")), rb_ivar_get(rctx, rb_intern("@eheader"))) ||
                parse_directive_include_(rctx, "%source", rb_ivar_get(rctx, rb_intern("@source")), Qnil) ||
                parse_directive_include_(rctx, "%header", rb_ivar_get(rctx, rb_intern("@header")), Qnil) ||
                parse_directive_include_(rctx, "%common", rb_ivar_get(rctx, rb_intern("@source")), rb_ivar_get(rctx, rb_intern("@header"))) ||
                parse_directive_string_(rctx, "%value", "@value_type", STRING_FLAG__NOTEMPTY | STRING_FLAG__NOTVOID) ||
                parse_directive_string_(rctx, "%auxil", "@auxil_type", STRING_FLAG__NOTEMPTY | STRING_FLAG__NOTVOID) ||
                parse_directive_string_(rctx, "%prefix", "@prefix", STRING_FLAG__NOTEMPTY | STRING_FLAG__IDENTIFIER)
            ) {
                b = TRUE;
            }
            else if (RB_TEST(rb_funcall(rctx, rb_intern("match_character"), 1, INT2NUM('%')))) {
                print_error("%s:" FMT_LU ":" FMT_LU ": Invalid directive\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1));
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
                match_identifier(rctx);
                match_spaces(rctx);
                b = TRUE;
            }
            else {
                VALUE rnode, rrules;
                rnode = parse_rule(rctx);
                if (rnode == Qnil) {
                    if (b) {
                        print_error("%s:" FMT_LU ":" FMT_LU ": Illegal rule syntax\n", RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))), (ulong_t)(l + 1), (ulong_t)(m + 1));
                        rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
                        b = FALSE;
                    }
                    rb_ivar_set(rctx, rb_intern("@linenum"), SIZET2NUM(l));
                    rb_ivar_set(rctx, rb_intern("@charnum"), SIZET2NUM(n));
                    rb_ivar_set(rctx, rb_intern("@linepos"), SIZET2NUM(o));
                    if (!match_identifier(rctx) && !match_spaces(rctx)) RB_TEST(rb_funcall(rctx, rb_intern("match_character_any"), 0));
                    continue;
                }
                rrules = rb_ivar_get(rctx, rb_intern("@rules"));
                rb_ary_push(rrules, rnode);
                b = TRUE;
            }
            rb_funcall(rctx, rb_intern("commit_buffer"), 0);
        }
        rb_funcall(rctx, rb_intern("commit_buffer"), 0);
    }
    {
        size_t i;
        VALUE rrules, rnode;
        node_t *node;
        rb_funcall(rctx, rb_intern("make_rulehash"), 0);
        rrules = rb_ivar_get(rctx, rb_intern("@rules"));
        for (i = 0; i < (size_t)RARRAY_LEN(rrules); i++) {
            rnode = rb_ary_entry(rrules, i);
            TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
            link_references(rctx, node->data.rule.expr);
        }
        for (i = 1; i < (size_t)RARRAY_LEN(rrules); i++) {
            rnode = rb_ary_entry(rrules, i);
            TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
            if (node->data.rule.ref == 0) {
                print_error("%s:" FMT_LU ":" FMT_LU ": Never used rule '%s'\n",
                    RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))),
                    (ulong_t)(node->data.rule.line + 1), (ulong_t)(node->data.rule.col + 1),
                    node->data.rule.name);
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
            }
            else if (node->data.rule.ref < 0) {
                print_error("%s:" FMT_LU ":" FMT_LU ": Multiple definition of rule '%s'\n",
                    RSTRING_PTR(rb_ivar_get(rctx, rb_intern("@iname"))),
                    (ulong_t)(node->data.rule.line + 1), (ulong_t)(node->data.rule.col + 1),
                    node->data.rule.name);
                rb_ivar_set(rctx, rb_intern("@errnum"), rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("succ"), 0));
            }
        }
    }
    {
        size_t i;
        VALUE rrules;
        node_t *node;
        rrules = rb_ivar_get(rctx, rb_intern("@rules"));
        for (i = 0; i < (size_t)RARRAY_LEN(rrules); i++) {
            VALUE rnode = rb_ary_entry(rrules, i);
            TypedData_Get_Struct(rnode, node_t, &packcr_ptr_data_type, node);
            verify_variables(rctx, node->data.rule.expr, NULL);
            verify_captures(rctx, node->data.rule.expr, NULL);
        }
    }
    if (RB_TEST(rb_ivar_get(rctx, rb_intern("@debug")))) {
        size_t i;
        VALUE rrules = rb_ivar_get(rctx, rb_intern("@rules"));
        for (i = 0; i < (size_t)RARRAY_LEN(rrules); i++) {
            VALUE rnode = rb_ary_entry(rrules, i);
            dump_node(rctx, rnode, 0);
        }
        dump_options(rctx);
    }

    return RB_TEST(rb_funcall(rb_ivar_get(rctx, rb_intern("@errnum")), rb_intern("zero?"), 0)) ? TRUE : FALSE;
}
