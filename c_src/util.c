#include "util.h"

#include <string.h>

#include "impl.h"

ERL_NIF_TERM make_atom(ErlNifEnv *env, const char *atom_name) {
  ERL_NIF_TERM atom;
  if (enif_make_existing_atom(env, atom_name, &atom, ERL_NIF_LATIN1)) {
    return atom;
  }
  return enif_make_atom(env, atom_name);
}

ERL_NIF_TERM make_ok_tuple(ErlNifEnv *env, ERL_NIF_TERM value) {
  return enif_make_tuple2(env, make_atom(env, "ok"), value);
}

ERL_NIF_TERM make_error_tuple(ErlNifEnv *env, ERL_NIF_TERM reason) {
  return enif_make_tuple2(env, make_atom(env, "error"), reason);
}

ERL_NIF_TERM make_errno_tuple(ErlNifEnv *env) {
  return make_error_tuple(env, make_errno_term(env));
}

ERL_NIF_TERM make_bool(ErlNifEnv *env, bool value) {
  return make_atom(env, value ? "true" : "false");
}

ERL_NIF_TERM make_elixir_string(ErlNifEnv *env, const char *string) {
  ERL_NIF_TERM result;
  size_t len;
  unsigned char *data;

  len = strlen(string);
  data = enif_make_new_binary(env, len * sizeof(char), &result);
  strncpy((char *)data, string, len);

  return result;
}
