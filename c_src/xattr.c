#include <erl_nif.h>
#include <errno.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "impl.h"
#include "util.h"

/*
 * Exported NIFs
 */

/** @spec listxattr_nif(binary) :: {:ok, list(binary)} | {:error, term} */
static ERL_NIF_TERM listxattr_nif(ErlNifEnv *env, int argc,
                                  const ERL_NIF_TERM argv[]) {
  ErlNifBinary path;
  ERL_NIF_TERM list;

  if (argc != 1) {
    return enif_make_badarg(env);
  }

  if (!enif_inspect_binary(env, argv[0], &path)) {
    return enif_make_badarg(env);
  }

  if (path.size == 0) {
    enif_release_binary(&path);
    return enif_make_badarg(env);
  }

  if (!listxattr_impl(env, (char *)path.data, &list)) {
    enif_release_binary(&path);
    return make_errno_tuple(env);
  }

  enif_release_binary(&path);
  return make_ok_tuple(env, list);
}

/** @spec hasxattr_nif(binary, binary) :: {:ok, boolean} | {:error, term} */
static ERL_NIF_TERM hasxattr_nif(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]) {
  ErlNifBinary path;
  ErlNifBinary name;
  bool result;

  if (argc != 2) {
    return enif_make_badarg(env);
  }

  if (!enif_inspect_binary(env, argv[0], &path)) {
    return enif_make_badarg(env);
  }

  if (path.size == 0) {
    enif_release_binary(&path);
    return enif_make_badarg(env);
  }

  if (!enif_inspect_binary(env, argv[1], &name)) {
    enif_release_binary(&path);
    return enif_make_badarg(env);
  }

  if (name.size == 0) {
    enif_release_binary(&name);
    enif_release_binary(&path);
    return enif_make_badarg(env);
  }

  if (!hasxattr_impl(env, (char *)path.data, (char *)name.data, &result)) {
    enif_release_binary(&name);
    enif_release_binary(&path);
    return make_errno_tuple(env);
  }

  enif_release_binary(&name);
  enif_release_binary(&path);

  return make_ok_tuple(env, make_bool(env, result));
}

/** @spec getxattr_nif(binary, binary) :: {:ok, binary} | {:error, term} */
static ERL_NIF_TERM getxattr_nif(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]) {
  ErlNifBinary path;
  ErlNifBinary name;
  ErlNifBinary result;

  if (argc != 2) {
    return enif_make_badarg(env);
  }

  if (!enif_inspect_binary(env, argv[0], &path)) {
    return enif_make_badarg(env);
  }

  if (path.size == 0) {
    enif_release_binary(&path);
    return enif_make_badarg(env);
  }

  if (!enif_inspect_binary(env, argv[1], &name)) {
    enif_release_binary(&path);
    return enif_make_badarg(env);
  }

  if (name.size == 0) {
    enif_release_binary(&name);
    enif_release_binary(&path);
    return enif_make_badarg(env);
  }

  if (!getxattr_impl(env, (char *)path.data, (char *)name.data, &result)) {
    enif_release_binary(&name);
    enif_release_binary(&path);
    enif_release_binary(&result);
    return make_errno_tuple(env);
  }

  enif_release_binary(&name);
  enif_release_binary(&path);

  return make_ok_tuple(env, enif_make_binary(env, &result));
}

/** @spec setxattr_nif(binary, binary, binary) :: :ok | {:error, term} */
static ERL_NIF_TERM setxattr_nif(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]) {
  ErlNifBinary path;
  ErlNifBinary name;
  ErlNifBinary value;

  if (argc != 3) {
    return enif_make_badarg(env);
  }

  if (!enif_inspect_binary(env, argv[0], &path)) {
    return enif_make_badarg(env);
  }

  if (path.size == 0) {
    enif_release_binary(&path);
    return enif_make_badarg(env);
  }

  if (!enif_inspect_binary(env, argv[1], &name)) {
    enif_release_binary(&path);
    return enif_make_badarg(env);
  }

  if (name.size == 0) {
    enif_release_binary(&name);
    enif_release_binary(&path);
    return enif_make_badarg(env);
  }

  if (!enif_inspect_binary(env, argv[2], &value)) {
    enif_release_binary(&name);
    enif_release_binary(&path);
    return enif_make_badarg(env);
  }

  if (!setxattr_impl(env, (char *)path.data, (char *)name.data, value)) {
    enif_release_binary(&name);
    enif_release_binary(&path);
    enif_release_binary(&value);
    return make_errno_tuple(env);
  }

  enif_release_binary(&name);
  enif_release_binary(&path);
  enif_release_binary(&value);

  return make_atom(env, "ok");
}

/** removexattr_nif(binary, binary) :: :ok | {:error, term} */
static ERL_NIF_TERM removexattr_nif(ErlNifEnv *env, int argc,
                                    const ERL_NIF_TERM argv[]) {
  ErlNifBinary path;
  ErlNifBinary name;

  if (argc != 2) {
    return enif_make_badarg(env);
  }

  if (!enif_inspect_binary(env, argv[0], &path)) {
    return enif_make_badarg(env);
  }

  if (path.size == 0) {
    enif_release_binary(&path);
    return enif_make_badarg(env);
  }

  if (!enif_inspect_binary(env, argv[1], &name)) {
    enif_release_binary(&path);
    return enif_make_badarg(env);
  }

  if (name.size == 0) {
    enif_release_binary(&name);
    enif_release_binary(&path);
    return enif_make_badarg(env);
  }

  if (!removexattr_impl(env, (char *)path.data, (char *)name.data)) {
    enif_release_binary(&name);
    enif_release_binary(&path);
    return make_errno_tuple(env);
  }

  enif_release_binary(&name);
  enif_release_binary(&path);

  return make_atom(env, "ok");
}

/*
 * NIF setup
 */

static ErlNifFunc nif_funcs[] = {
    {"listxattr_nif", 1, listxattr_nif, 0},
    {"hasxattr_nif", 2, hasxattr_nif, 0},
    {"getxattr_nif", 2, getxattr_nif, 0},
    {"setxattr_nif", 3, setxattr_nif, 0},
    {"removexattr_nif", 2, removexattr_nif, 0},
};

ERL_NIF_INIT(Elixir.Xattr.Nif, nif_funcs, NULL, NULL, NULL, NULL)
