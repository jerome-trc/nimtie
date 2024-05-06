#pragma once

#define SIMPLE_CONST 123

typedef char SimpleEnum;
#define FIRST 0
#define SECOND 1
#define THIRD 2

typedef struct SimpleObj {
  long long simple_a;
  char simple_b;
  char simple_c;
} SimpleObj;

typedef long long SimpleRefObj;

typedef long long SeqInt;

typedef long long RefObjWithSeq;

typedef struct SimpleObjWithProc {
  long long simple_a;
  char simple_b;
  char simple_c;
} SimpleObjWithProc;

typedef long long SeqString;

/**
 * Returns the integer passed in.
 */
long long _simple_call(long long a);

SimpleObj _simple_obj(long long simple_a, char simple_b, char simple_c);

char _simple_obj_eq(SimpleObj a, SimpleObj b);

void _simple_ref_obj_unref(SimpleRefObj simple_ref_obj);

SimpleRefObj _new_simple_ref_obj();

long long _simple_ref_obj_get_simple_ref_a(SimpleRefObj simple_ref_obj);

void _simple_ref_obj_set_simple_ref_a(SimpleRefObj simple_ref_obj, long long value);

char _simple_ref_obj_get_simple_ref_b(SimpleRefObj simple_ref_obj);

void _simple_ref_obj_set_simple_ref_b(SimpleRefObj simple_ref_obj, char value);

/**
 * Does some thing with SimpleRefObj.
 */
void _simple_ref_obj_doit(SimpleRefObj s);

void _seq_int_unref(SeqInt seq_int);

SeqInt _new_seq_int();

long long _seq_int_len(SeqInt seq_int);

long long _seq_int_get(SeqInt seq_int, long long index);

void _seq_int_set(SeqInt seq_int, long long index, long long value);

void _seq_int_delete(SeqInt seq_int, long long index);

void _seq_int_add(SeqInt seq_int, long long value);

void _seq_int_clear(SeqInt seq_int);

void _ref_obj_with_seq_unref(RefObjWithSeq ref_obj_with_seq);

RefObjWithSeq _new_ref_obj_with_seq();

long long _ref_obj_with_seq_data_len(RefObjWithSeq ref_obj_with_seq);

char _ref_obj_with_seq_data_get(RefObjWithSeq ref_obj_with_seq, long long index);

void _ref_obj_with_seq_data_set(RefObjWithSeq ref_obj_with_seq, long long index, char value);

void _ref_obj_with_seq_data_delete(RefObjWithSeq ref_obj_with_seq, long long index);

void _ref_obj_with_seq_data_add(RefObjWithSeq ref_obj_with_seq, char value);

void _ref_obj_with_seq_data_clear(RefObjWithSeq ref_obj_with_seq);

SimpleObjWithProc _simple_obj_with_proc(long long simple_a, char simple_b, char simple_c);

char _simple_obj_with_proc_eq(SimpleObjWithProc a, SimpleObjWithProc b);

void _simple_obj_with_proc_extra_proc(SimpleObjWithProc s);

void _seq_string_unref(SeqString seq_string);

SeqString _new_seq_string();

long long _seq_string_len(SeqString seq_string);

char* _seq_string_get(SeqString seq_string, long long index);

void _seq_string_set(SeqString seq_string, long long index, char* value);

void _seq_string_delete(SeqString seq_string, long long index);

void _seq_string_add(SeqString seq_string, char* value);

void _seq_string_clear(SeqString seq_string);

SeqString _get_datas();

