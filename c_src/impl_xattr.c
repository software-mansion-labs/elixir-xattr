#include "impl.h"

#include "util.h"
#include <stdio.h>
#include <string.h>

#include <errno.h>
#include <sys/types.h>
#include <sys/xattr.h>

#define NSUSER_PREFIX ("user.ElixirXattr.")
#define NSUSER_LENGTH (sizeof(NSUSER_PREFIX) / sizeof(char) - 1)

#define TO_BOOL(result) ((result == 0) ? true : false)

static bool is_user_namespace(const char *name, size_t len) {
  return len > NSUSER_LENGTH &&
         strncmp(NSUSER_PREFIX, name, NSUSER_LENGTH) == 0;
}

static char *prepend_user_prefix(const char *name) {
  char *buff;
  size_t buff_size = sizeof(NSUSER_PREFIX) + (strlen(name) + 1) * sizeof(char);

  if ((buff = enif_alloc(buff_size)) == NULL) {
    errno = ERANGE;
    return NULL;
  }

  sprintf(buff, "%s%s", NSUSER_PREFIX, name);
  return buff;
}

bool listxattr_impl(ErlNifEnv *env, const char *path, ERL_NIF_TERM *list) {
  const char *buff_ptr;
  ERL_NIF_TERM entry;
  ErlNifBinary buff;
  size_t namelen;
  ssize_t bsize;

  if ((bsize = listxattr(path, NULL, 0)) == -1) {
    return false;
  }

  if (!enif_alloc_binary(bsize, &buff)) {
    errno = ERANGE;
    return false;
  }

  while ((bsize = listxattr(path, (char *)buff.data, buff.size)) == -1) {
    if (errno == ERANGE) {
      bsize = buff.size * 2;
      if (!enif_realloc_binary(&buff, bsize)) {
        errno = ERANGE;
        return false;
      }
      /* continue with bigger buffer */
    } else {
      return false;
    }
  }

  *list = enif_make_list(env, 0);
  buff_ptr = (char *)buff.data;

  while (bsize != 0) {
    namelen = strlen(buff_ptr);
    if (is_user_namespace(buff_ptr, namelen)) {
      entry = make_elixir_string(env, buff_ptr + NSUSER_LENGTH);
      *list = enif_make_list_cell(env, entry, *list);
    }
    buff_ptr += namelen + 1;
    bsize -= namelen + 1;
  }

  return true;
}

bool hasxattr_impl(UNUSED ErlNifEnv *env, const char *path, const char *name,
                   bool *result) {
  char *real_name;
  ssize_t r;

  if ((real_name = prepend_user_prefix(name)) == NULL) {
    return false;
  }

  if ((r = getxattr(path, real_name, NULL, 0)) == -1) {
    if (errno == ENODATA) {
      errno = 0;
      *result = false;
      enif_free(real_name);
      return true;
    } else {
      enif_free(real_name);
      return false;
    }
  } else {
    *result = true;
    enif_free(real_name);
    return true;
  }
}

bool getxattr_impl(UNUSED ErlNifEnv *env, const char *path, const char *name,
                   ErlNifBinary *bin) {
  char *real_name;
  ssize_t new_size;
  ssize_t result;

  if ((real_name = prepend_user_prefix(name)) == NULL) {
    return false;
  }

  if ((new_size = getxattr(path, real_name, NULL, 0)) == -1) {
    enif_free(real_name);
    return false;
  }

  if (!enif_alloc_binary(new_size, bin)) {
    errno = ERANGE;
    enif_free(real_name);
    return false;
  }

  while ((result = getxattr(path, real_name, bin->data, bin->size)) == -1) {
    if (errno == ERANGE) {
      new_size = bin->size * 2;
      if (!enif_realloc_binary(bin, new_size)) {
        errno = ERANGE;
        enif_free(real_name);
        return false;
      }
      /* continue with bigger buffer */
    } else {
      enif_free(real_name);
      return false;
    }
  }

  enif_free(real_name);
  return true;
}

bool setxattr_impl(UNUSED ErlNifEnv *env, const char *path, const char *name,
                   const ErlNifBinary value) {
  char *real_name;
  int result;

  if ((real_name = prepend_user_prefix(name)) == NULL) {
    return false;
  }

  result = setxattr(path, real_name, value.data, value.size, 0);

  enif_free(real_name);
  return TO_BOOL(result);
}

bool removexattr_impl(UNUSED ErlNifEnv *env, const char *path,
                      const char *name) {
  char *real_name;
  int result;

  if ((real_name = prepend_user_prefix(name)) == NULL) {
    return false;
  }

  result = removexattr(path, real_name);

  enif_free(real_name);
  return TO_BOOL(result);
}

ERL_NIF_TERM make_errno_term(ErlNifEnv *env) {
  switch (errno) {
  case E2BIG: return make_atom(env, "e2big");
  case EAGAIN: return make_atom(env, "eagain");
  case EDQUOT: return make_atom(env, "edquot");
  case EFAULT: return make_atom(env, "efault");
  case ENODATA: return make_atom(env, "enoattr");
  case ENOENT: return make_atom(env, "enoent");
  case ENOSPC: return make_atom(env, "enospc");
  case ENOTSUP: return make_atom(env, "enotsup");
  case EPERM: return make_atom(env, "eperm");
  case ERANGE: return make_atom(env, "erange");
  default: return enif_make_string(env, strerror(errno), ERL_NIF_LATIN1);
  }
}
