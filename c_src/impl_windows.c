#include "impl.h"

#include "util.h"
#include <stdint.h>
#include <string.h>

#include <strsafe.h>
#include <windows.h>

#define ADSNAME (L"ElixirXattr")
#define ADSNAME_LENGTH (sizeof(ADSNAME) / sizeof(wchar_t) - 1)

#define ERR_ENIF_ALLOC 0x20000001
#define ERR_INVALID_FORMAT 0x20000002
#define ERR_NOATTR 0x20000003

/*
 * Utilities
 */

static bool ws_to_utf8(LPCWSTR in, _Out_ LPSTR *out) {
  int outsize;

  if (*in == L'\0') {
    *out = enif_alloc(sizeof(char));
    if (*out == NULL) {
      SetLastError(ERR_ENIF_ALLOC);
      return false;
    }
    **out = '\0';
    return true;
  }

  outsize = WideCharToMultiByte(CP_UTF8, 0, in, -1, NULL, 0, NULL, NULL);

  *out = enif_alloc((outsize + 1) * sizeof(char));
  if (*out == NULL) {
    SetLastError(ERR_ENIF_ALLOC);
    return false;
  }

  WideCharToMultiByte(CP_UTF8, 0, in, -1, *out, outsize, NULL, NULL);

  return true;
}

static bool utf8_to_ws(LPCSTR in, _Out_ LPWSTR *out) {
  int outsize;

  if (*in == '\0') {
    *out = enif_alloc(sizeof(wchar_t));
    if (*out == NULL)
      return false;
    **out = L'\0';
    return true;
  }

  outsize = MultiByteToWideChar(CP_UTF8, 0, in, -1, NULL, 0);

  *out = enif_alloc((outsize + 1) * sizeof(wchar_t));
  if (*out == NULL)
    return false;

  MultiByteToWideChar(CP_UTF8, 0, in, -1, *out, outsize);

  return true;
}

static LPWSTR get_adspath(const char *path) {
  LPWSTR buff;
  LPWSTR wpath = NULL;
  size_t bufflen;

  if (!utf8_to_ws(path, &wpath)) {
    return NULL;
  }

  bufflen = wcslen(wpath) + 1 + ADSNAME_LENGTH + 1;
  if ((buff = enif_alloc(bufflen * sizeof(wchar_t))) == NULL) {
    enif_free(wpath);
    SetLastError(ERR_ENIF_ALLOC);
    return NULL;
  }

  StringCchPrintfW(buff, bufflen, L"%s:%s", wpath, ADSNAME);

  enif_free(wpath);
  return buff;
}

static bool file_exists(LPCWSTR path) {
  DWORD attr = GetFileAttributesW(path);
  return attr != INVALID_FILE_ATTRIBUTES && !(attr & FILE_ATTRIBUTE_DIRECTORY);
}

/**
 * \returns  0 - success,
 *          >0 - IO error,
 *          -1 - stream doesn't exist (if `create == false`)
 */
static int get_data_stream(const char *filepath, bool ro, bool create,
                           _Out_ HANDLE *file_handle) {
  DWORD last_error;
  HANDLE h;
  LPWSTR adspath;

  if ((adspath = get_adspath(filepath)) == NULL) {
    return 2;
  }

  h = CreateFileW(adspath, (ro ? GENERIC_READ : (GENERIC_READ | GENERIC_WRITE)),
                  0, NULL, (create ? OPEN_ALWAYS : OPEN_EXISTING), 0, NULL);
  last_error = GetLastError(); // save last error in variable, because
                               // something likes to put 0x0 there

  enif_free(adspath);

  if (h == INVALID_HANDLE_VALUE) {
    if (!create && last_error == ERROR_FILE_NOT_FOUND) {
      SetLastError(NO_ERROR);
      return -1;
    } else {
      SetLastError(last_error);
      return 1;
    }
  } else {
    *file_handle = h;

    if (create && last_error == ERROR_ALREADY_EXISTS) {
      SetLastError(NO_ERROR);
    }

    return 0;
  }
}

/*
 * Xattr file parser
 */

typedef enum { XEVT_ERROR, XEVT_EOF, XEVT_NAME, XEVT_VALUE } xevt_type_t;

typedef struct {
  xevt_type_t type;
  size_t size;
  void *data;
} xevt_t;

typedef struct {
  HANDLE h;
  ErlNifBinary buffer;
  bool on_value;
  bool skip_values;
} xparser_t;

static bool xparser_init(xparser_t *p, HANDLE file_handle, bool skip_values) {
  p->h = file_handle;

  if (!enif_alloc_binary(512, &p->buffer)) {
    SetLastError(ERR_ENIF_ALLOC);
    return false;
  }

  p->on_value = false;
  p->skip_values = skip_values;

  return true;
}

static void xparser_release(xparser_t *p) { enif_release_binary(&p->buffer); }

static bool xparser_next(xparser_t *p, xevt_t *evt) {
  DWORD fptr;
  DWORD last_error;
  DWORD nb_read = 0;
  uint32_t block_size = 0;

  memset(evt, 0, sizeof(*evt));

  // read block size
  if (!ReadFile(p->h, &block_size, sizeof(uint32_t), &nb_read, NULL)) {
    evt->type = XEVT_ERROR;
    return false;
  }

  // check whether we haven't reached EOF
  if (nb_read == 0) {
    evt->type = XEVT_EOF;
    return false;
  }

  // check we have read whole uint32
  if (nb_read != sizeof(uint32_t)) {
    evt->type = XEVT_ERROR;
    SetLastError(ERR_INVALID_FORMAT);
    return false;
  }

  if (p->skip_values && p->on_value) {
    // skip value

    fptr = SetFilePointer(p->h, (LONG)block_size, NULL, FILE_CURRENT);
    last_error = GetLastError();

    if (fptr == INVALID_SET_FILE_POINTER) {
      evt->type = XEVT_ERROR;
      SetLastError(last_error);
      return false;
    }

    p->on_value = !p->on_value;
    // and retry, we are now parsing name
    return xparser_next(p, evt);
  } else {
    // read name/value and store it in buffer

    // ensure our buffer is large enough
    if (block_size + 1 > p->buffer.size) {
      if (!enif_realloc_binary(&p->buffer, block_size + 1)) {
        evt->type = XEVT_ERROR;
        SetLastError(ERR_ENIF_ALLOC);
        return false;
      }
    }

    // we allow empty blocks
    if (block_size > 0) {
      // read block
      if (!ReadFile(p->h, p->buffer.data, block_size, &nb_read, NULL)) {
        evt->type = XEVT_ERROR;
        return false;
      }

      // check whether we have read whole block
      if (nb_read != block_size) {
        evt->type = XEVT_ERROR;
        SetLastError(ERR_INVALID_FORMAT);
        return false;
      }
    }

    evt->type = (p->on_value ? XEVT_VALUE : XEVT_NAME);
    evt->size = block_size;
    evt->data = (void *)p->buffer.data;

    p->on_value = !p->on_value;
    return true;
  }
}

/*
 * Xattr write functions
 */

bool write_block(HANDLE file_handle, const void *data, uint32_t size) {
  bool r;
  DWORD nb_written;

  r = WriteFile(file_handle, &size, sizeof(size), &nb_written, NULL);
  if (!r) {
    return false;
  }

  /* FIXME: what if we haven't written everything? */

  r = WriteFile(file_handle, data, size, &nb_written, NULL);
  return r;
}

bool write_binary(HANDLE file_handle, const ErlNifBinary bin) {
  return write_block(file_handle, bin.data, (uint32_t)bin.size);
}

bool write_cstring(HANDLE file_handle, const char *str) {
  return write_block(file_handle, str, (strlen(str) + 1) * sizeof(char));
}

/*
 * Implementation functions
 */

bool listxattr_impl(ErlNifEnv *env, const char *path, ERL_NIF_TERM *list) {
  DWORD last_error;
  ERL_NIF_TERM entry;
  HANDLE ds;
  int result;
  xevt_t evt;
  xparser_t parser;

  result = get_data_stream(path,
                           true,  // read-only
                           false, // do not create if not exists
                           &ds);
  if (result == 0) {
    // Xattr stream exists

    if (!xparser_init(&parser, ds, true)) {
      last_error = GetLastError();
      CloseHandle(ds);
      SetLastError(last_error);
      return false;
    }

    *list = enif_make_list(env, 0);

    while (xparser_next(&parser, &evt)) {
      if (evt.type == XEVT_NAME) {
        entry = make_elixir_string(env, (char *)evt.data);
        *list = enif_make_list_cell(env, entry, *list);
      } else {
        fprintf(stderr, "ElixirXattr: unexpected event %d\n", evt.type);
      }
    }

    last_error = GetLastError();

    if (evt.type == XEVT_EOF) {
      xparser_release(&parser);
      CloseHandle(ds);
      return true;
    } else {
      xparser_release(&parser);
      CloseHandle(ds);

      if (evt.type != XEVT_ERROR) {
        fprintf(stderr, "ElixirXattr: unexpected event %d\n", evt.type);
        SetLastError(ERR_INVALID_FORMAT);
      } else {
        SetLastError(last_error);
      }

      return false;
    }
  } else if (result == -1) {
    // Return empty list if there is no xattr stream
    *list = enif_make_list(env, 0);
    return true;
  } else {
    // Error
    return false;
  }
}

bool hasxattr_impl(ErlNifEnv *env, const char *path, const char *name,
                   bool *returnValue) {
  DWORD last_error;
  HANDLE ds;
  int result;
  xevt_t evt;
  xparser_t parser;

  result = get_data_stream(path,
                           true,  // read-only
                           false, // do not create if not exists
                           &ds);
  if (result == 0) {
    // Xattr stream exists

    if (!xparser_init(&parser, ds, true)) {
      last_error = GetLastError();
      CloseHandle(ds);
      SetLastError(last_error);
      return false;
    }

    while (xparser_next(&parser, &evt)) {
      if (evt.type == XEVT_NAME) {
        if (strcmp(name, (char *)evt.data) == 0) {
          xparser_release(&parser);
          CloseHandle(ds);
          *returnValue = true;
          return true;
        }
      } else {
        fprintf(stderr, "ElixirXattr: unexpected event %d\n", evt.type);
      }
    }

    last_error = GetLastError();

    if (evt.type == XEVT_EOF) {
      xparser_release(&parser);
      CloseHandle(ds);
      *returnValue = false;
      return true;
    } else {
      xparser_release(&parser);
      CloseHandle(ds);

      if (evt.type != XEVT_ERROR) {
        fprintf(stderr, "ElixirXattr: unexpected event %d\n", evt.type);
        SetLastError(ERR_INVALID_FORMAT);
      } else {
        SetLastError(last_error);
      }

      return false;
    }
  } else if (result == -1) {
    // Return false if there is no xattr stream
    *returnValue = false;
    return true;
  } else {
    // Error
    return false;
  }
}

bool getxattr_impl(ErlNifEnv *env, const char *path, const char *name,
                   ErlNifBinary *bin) {
  bool found = false;
  DWORD last_error;
  HANDLE ds;
  int result;
  xevt_t evt;
  xparser_t parser;

  result = get_data_stream(path,
                           true,  // read-only
                           false, // do not create if not exists
                           &ds);
  if (result == 0) {
    // Xattr stream exists

    if (!xparser_init(&parser, ds, false)) {
      last_error = GetLastError();
      CloseHandle(ds);
      SetLastError(last_error);
      return false;
    }

    while (xparser_next(&parser, &evt)) {
      if (evt.type == XEVT_NAME) {
        if (strcmp(name, (char *)evt.data) == 0) {
          found = true;
        }
      } else if (evt.type == XEVT_VALUE) {
        if (found) {
          if (!enif_alloc_binary(evt.size, bin)) {
            xparser_release(&parser);
            CloseHandle(ds);
            SetLastError(ERR_ENIF_ALLOC);
            return false;
          }

          memcpy(bin->data, evt.data, evt.size);

          xparser_release(&parser);
          CloseHandle(ds);
          return true;
        }
        // otherwise continue searching...
      } else {
        fprintf(stderr, "ElixirXattr: unexpected event %d\n", evt.type);
      }
    }

    last_error = GetLastError();

    if (evt.type == XEVT_EOF) {
      xparser_release(&parser);
      CloseHandle(ds);
      SetLastError(ERR_NOATTR);
      return false;
    } else {
      xparser_release(&parser);
      CloseHandle(ds);

      if (evt.type != XEVT_ERROR) {
        fprintf(stderr, "ElixirXattr: unexpected event %d\n", evt.type);
        SetLastError(ERR_INVALID_FORMAT);
      } else {
        SetLastError(last_error);
      }

      return false;
    }
  } else if (result == -1) {
    // Return false if there is no xattr stream
    SetLastError(ERR_NOATTR);
    return false;
  } else {
    // Error
    return false;
  }
}

/**
 * Move attribute to the end of xattr file and place file pointer on beginning
 * of this attribute.
 *
 * Returns false and sets last error to ERR_NOATTR if attribute wasn't found,
 * the pointer is then set to the EOF.
 */
static bool move_attr_to_end(HANDLE ds, const char *name) {
  bool found = false;
  bool result;
  DWORD last_error;
  DWORD nb_read = 0;
  DWORD nb_written = 0;
  DWORD readptr;
  DWORD writeptr;
  DWORD window_width;
  ErlNifBinary found_value;
  void *buffer;
  xevt_t evt;
  xparser_t parser;

  if (!xparser_init(&parser, ds, false)) {
    return false;
  }

  // skip all attributes until we find `name`
  while (!found && xparser_next(&parser, &evt)) {
    if (evt.type == XEVT_NAME) {
      if (strcmp(name, (char *)evt.data) == 0) {
        // we found our attribute

        // read & save its value
        result = xparser_next(&parser, &evt);
        if (result && evt.type == XEVT_VALUE) {
          if (!enif_alloc_binary(evt.size, &found_value)) {
            xparser_release(&parser);
            SetLastError(ERR_ENIF_ALLOC);
            return false;
          }

          memcpy(evt.data, found_value.data, evt.size);
        } else if (!result && evt.type == XEVT_EOF) {
          xparser_release(&parser);
          SetLastError(ERR_INVALID_FORMAT);
          return false;
        } else {
          last_error = GetLastError();
          xparser_release(&parser);
          SetLastError(last_error);
          return false;
        }

        found = true;
      }
    } else if (evt.type == XEVT_VALUE) {
      // skip value
    } else {
      fprintf(stderr, "ElixirXattr: unexpected event %d\n", evt.type);
    }
  }

  if (!found) {
    // previous loop has iterated over whole file or errored
    if (evt.type == XEVT_EOF) {
      xparser_release(&parser);
      SetLastError(ERR_NOATTR);
      return false;
    } else {
      last_error = GetLastError();
      xparser_release(&parser);
      SetLastError(last_error);
      return false;
    }
  }

  // Release parser as we won't need it anymore
  xparser_release(&parser);

  // now compute window width = size of attribute representation
  // and shift rest data in bursts of 4kb
  window_width = sizeof(uint32_t) + (strlen(name) + 1) * sizeof(char) +
                 sizeof(uint32_t) + found_value.size;

  buffer = enif_alloc(4096);
  if (buffer == NULL) {
    enif_release_binary(&found_value);
    SetLastError(ERR_ENIF_ALLOC);
    return false;
  }

  readptr = SetFilePointer(ds, 0, NULL, FILE_CURRENT);

  do {
    readptr = SetFilePointer(ds, readptr, NULL, FILE_BEGIN);
    if (readptr == INVALID_SET_FILE_POINTER) {
      last_error = GetLastError();
      enif_release_binary(&found_value);
      enif_free(buffer);
      SetLastError(last_error);
      return false;
    }

    if (!ReadFile(ds, buffer, 4096, &nb_read, NULL)) {
      last_error = GetLastError();
      enif_release_binary(&found_value);
      enif_free(buffer);
      SetLastError(last_error);
      return false;
    }

    readptr = SetFilePointer(ds, 0, NULL, FILE_CURRENT);

    writeptr = SetFilePointer(ds, -window_width - nb_read, NULL, FILE_CURRENT);
    if (writeptr == INVALID_SET_FILE_POINTER) {
      last_error = GetLastError();
      enif_release_binary(&found_value);
      enif_free(buffer);
      SetLastError(last_error);
      return false;
    }

    if (!WriteFile(ds, buffer, nb_read, &nb_written, NULL)) {
      last_error = GetLastError();
      enif_release_binary(&found_value);
      enif_free(buffer);
      SetLastError(last_error);
      return false;
    }

    /* FIXME: what if we haven't written everything? */
  } while (nb_read > 0);

  enif_free(buffer);

  // now write our attribute at the end of file
  if (!write_cstring(ds, name)) {
    last_error = GetLastError();
    enif_release_binary(&found_value);
    SetLastError(last_error);
    return false;
  }

  if (!write_binary(ds, found_value)) {
    last_error = GetLastError();
    enif_release_binary(&found_value);
    SetLastError(last_error);
    return false;
  }

  // and move file pointer just before it
  writeptr = SetFilePointer(ds, -window_width, NULL, FILE_CURRENT);

  enif_release_binary(&found_value);
  return true;
}

bool setxattr_impl(ErlNifEnv *env, const char *path, const char *name,
                   const ErlNifBinary value) {
  DWORD last_error;
  HANDLE ds;
  int result;

  result = get_data_stream(path,
                           false, // read & write
                           true,  // create if not exists
                           &ds);
  if (result == 0) {
    // Xattr stream exists

    // Move attribute to end of file so we can easily overwrite it.
    if (!move_attr_to_end(ds, name)) {
      last_error = GetLastError();
      if (last_error != ERR_NOATTR) {
        CloseHandle(ds);
        SetLastError(last_error);
        return false;
      }
    }

    // Write name
    if (!write_cstring(ds, name)) {
      last_error = GetLastError();
      CloseHandle(ds);
      SetLastError(last_error);
      return false;
    }

    // Write new value
    if (!write_binary(ds, value)) {
      last_error = GetLastError();
      CloseHandle(ds);
      SetLastError(last_error);
      return false;
    }

    // Truncate file if new value was shorter then existing one
    SetEndOfFile(ds);

    CloseHandle(ds);
    return true;
  } else {
    // Error
    return false;
  }
}

bool removexattr_impl(ErlNifEnv *env, const char *path, const char *name) {
  DWORD last_error;
  HANDLE ds;
  int result;

  result = get_data_stream(path,
                           false, // read & write
                           false, // do not create if not exists
                           &ds);
  if (result == 0) {
    // Xattr stream exists

    // Move attribute to end of file and truncate file just before this attr.
    if (!move_attr_to_end(ds, name)) {
      last_error = GetLastError();
      CloseHandle(ds);
      SetLastError(last_error);
      return false;
    }

    SetEndOfFile(ds);

    CloseHandle(ds);
    return true;
  } else if (result == -1) {
    // Return false if there is no xattr stream
    SetLastError(ERR_NOATTR);
    return false;
  } else {
    // Error
    return false;
  }
}

static ERL_NIF_TERM fmt_win_error(ErlNifEnv *env, DWORD last_error) {
  ERL_NIF_TERM result;
  LPSTR buff = NULL;
  LPWSTR wbuff;

  if ((wbuff = enif_alloc(128)) == NULL) {
    return make_atom(env, "badalloc");
  }

  StringCchPrintfW(wbuff, 128, L"Windows Error 0x%X", last_error);

  if (!ws_to_utf8(wbuff, &buff)) {
    enif_free(wbuff);
    return make_atom(env, "badalloc");
  }

  result = enif_make_string(env, buff, ERL_NIF_LATIN1);

  enif_free(wbuff);
  enif_free(buff);
  return result;
}

ERL_NIF_TERM make_errno_term(ErlNifEnv *env) {
  DWORD last_error = GetLastError();
  switch (last_error) {
  case ERR_ENIF_ALLOC: return make_atom(env, "badalloc");
  case ERR_INVALID_FORMAT: return make_atom(env, "invalfmt");
  case ERR_NOATTR: return make_atom(env, "enoattr");
  default: return fmt_win_error(env, last_error);
  }
}
