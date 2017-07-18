#ifndef ELIXIR_XATTR_UTIL_H
#define ELIXIR_XATTR_UTIL_H

#include <erl_nif.h>
#include <stdbool.h>
#include <stdlib.h>

#ifdef __GNUC__
#define UNUSED __attribute__((__unused__))
#else
#define UNUSED
#endif

ERL_NIF_TERM make_atom(ErlNifEnv *env, const char *atom_name);
ERL_NIF_TERM make_ok_tuple(ErlNifEnv *env, ERL_NIF_TERM value);
ERL_NIF_TERM make_error_tuple(ErlNifEnv *env, ERL_NIF_TERM reason);
ERL_NIF_TERM make_errno_term(ErlNifEnv *env);
ERL_NIF_TERM make_errno_tuple(ErlNifEnv *env);
ERL_NIF_TERM make_bool(ErlNifEnv *env, bool value);
ERL_NIF_TERM make_elixir_string(ErlNifEnv *env, const char *string);

#endif
