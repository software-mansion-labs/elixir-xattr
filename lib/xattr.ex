defmodule Xattr do
  import Xattr.Nif

  @moduledoc ~S"""
  API module for accessing custom extended filesystem attributes.

  Attributes managed by this module are stored in isolation, in custom namespace.
  Because implementation concepts of extended attributes differ in supported
  platforms, it would not be possible to provide unified API which could cover
  specific use cases.

  Some kernels and filesystems may place various limits on extended attributes
  functionality, and so it is to use them only to store few, short metadata which
  is not crucial to application functionality.

  ## Implementation

  Elixir Xattr is implemented as NIF library with two platform-dependent
  backends:
  * *Xattr* - Unix extended attributes supported by Linux and macOS
  * *Windows* - alternate data streams available in Windows/NTFS

  ### Xattr

  This backed works as an Erlang wrapper for [`xattr(7)`](http://man7.org/linux/man-pages/man7/xattr.7.html)
  functionality available in Unix world. Attributes are always prefixed with
  `user.ElixirXattr` namespace.

  ### Windows

  On Windows, NTFS has a feature called [*Alternate Data Streams*](https://blogs.technet.microsoft.com/askcore/2013/03/24/alternate-data-streams-in-ntfs/).
  Briefly: a file can have many contents.

  Attributes are stored in `ElixirXattr` data stream, which is automatically
  created when setting an attribute and the stream does not exist. They are
  saved in simple binary format, as a contiguous list of *size:data* cells:

  ```txt
    v - name C-string size                          v - value binary size
  +---+------------+---+-----------+---+----------+---+-------+
  | 5 | n a m e \0 | 5 | v a l u e | 4 | f o o \0 | 3 | b a r |  ...
  +---+------------+---+-----------+---+----------+---+-------+
        ^ - name C-string, note \0 suffix               ^ - value binary data
  ```

  ### Unicode

  Unicode filenames are supported (and as such proper encoding conversions
  are performed when needed).

  Both names nor values are not processed and stored as-is.

  ### Attribute name types

  Because attribute names can be represented by various Erlang types, they
  are prefixed with *type tags* during serialization:
  * `a$` - atoms
  * `s$` - name

  For example, given Xattr backend, call `Xattr.set("foo.txt", "example", "value")`
  will create `user.ElixirXattr.s$example` extended attribute on file `foo.txt`.

  ### Extended attributes & file system links

  On both Unix and Windows implementations, attribute storage is attached to
  file system data, not file/link entries. Therefore attributes are shared
  between all hard links / file and its symlinks.

  ## Errors

  Because of the nature of error handling on both Unix and Windows, only specific
  error codes are translated to atoms. Other codes are stringified to some human
  readable name, on Unix using [`strerror`](https://linux.die.net/man/3/strerror)
  and on Windows to form `'Windows Error {hexadecimal error code}'` (Windows
  version of strerror returns localized messages on non-English installations).

  Following errors are represented as atoms and as such can be pattern matched:

  * `:enoattr`  - attribute was not found
  * `:enotsup`  - extended attributes are not supported for this file
  * `:enoent`   - file does not exist
  * `:invalfmt` - attribute storage is corrupted and should be regenerated
  """

  @tag_atom "a$"
  @tag_str "s$"

  @type name_t :: String.t() | atom

  @doc """
  Lists names of all extended attributes of `path`.

  The order of items in returned list is unspecified. If given `path` has no
  attributes, `{:ok, []}` is returned.

  ## Example

      Xattr.set("foo.txt", "hello", "world")
      Xattr.set("foo.txt", :foo, "bar")
      {:ok, list} = Xattr.ls("foo.txt")
      # list should be permutation of ["hello", :foo]
  """
  @spec ls(Path.t()) :: {:ok, [name_t]} | {:error, term}
  def ls(path) do
    path = IO.chardata_to_string(path) <> <<0>>

    with {:ok, lst} <- listxattr_nif(path) do
      decode_list(lst)
    end
  end

  @doc """
  The same as `ls/1`, but raises an exception if it fails.
  """
  @spec ls!(Path.t()) :: [name_t] | no_return
  def ls!(path) do
    case ls(path) do
      {:ok, result} ->
        result

      {:error, reason} ->
        raise Xattr.Error,
          reason: reason,
          action: "list all extended attributes of",
          path: IO.chardata_to_string(path)
    end
  end

  @doc """
  Checks whether `path` has extended attribute `name`.

  ## Example

      Xattr.set("foo.txt", "hello", "world")
      Xattr.has("foo.txt", "hello") == {:ok, true}
      Xattr.has("foo.txt", :foo) == {:ok, false}
  """
  @spec has(Path.t(), name :: name_t) :: {:ok, boolean} | {:error, term}
  def has(path, name) when is_binary(name) or is_atom(name) do
    path = IO.chardata_to_string(path) <> <<0>>
    name = encode_name(name) <> <<0>>
    hasxattr_nif(path, name)
  end

  @doc """
  The same as `has/2`, but raises an exception if it fails.
  """
  @spec has!(Path.t(), name :: name_t) :: boolean | no_return
  def has!(path, name) do
    case has(path, name) do
      {:ok, result} ->
        result

      {:error, reason} ->
        raise Xattr.Error,
          reason: reason,
          action: "check attribute existence of",
          path: IO.chardata_to_string(path)
    end
  end

  @doc """
  Gets extended attribute value.

  If attribute `name` does not exist, `{:error, :enoattr}` is returned.

  ## Example

      Xattr.set("foo.txt", "hello", "world")
      Xattr.get("foo.txt", "hello") == {:ok, "world"}
      Xattr.get("foo.txt", :foo) == {:error, :enoattr}
  """
  @spec get(Path.t(), name :: name_t) :: {:ok, binary} | {:error, term}
  def get(path, name) when is_binary(name) or is_atom(name) do
    path = IO.chardata_to_string(path) <> <<0>>
    name = encode_name(name) <> <<0>>
    getxattr_nif(path, name)
  end

  @doc """
  The same as `get/2`, but raises an exception if it fails.
  """
  @spec get!(Path.t(), name :: name_t) :: binary | no_return
  def get!(path, name) do
    case get(path, name) do
      {:ok, result} ->
        result

      {:error, reason} ->
        raise Xattr.Error,
          reason: reason,
          action: "get attribute of",
          path: IO.chardata_to_string(path)
    end
  end

  @doc """
  Sets extended attribute value.

  If attribute `name` does not exist, it is created.

  ## Example

      Xattr.set("foo.txt", "hello", "world")
      Xattr.get("foo.txt", "hello") == {:ok, "world"}
  """
  @spec set(Path.t(), name :: name_t, value :: binary) :: :ok | {:error, term}
  def set(path, name, value)
      when (is_binary(name) or is_atom(name)) and is_binary(value) do
    path = IO.chardata_to_string(path) <> <<0>>
    name = encode_name(name) <> <<0>>
    setxattr_nif(path, name, value)
  end

  @doc """
  The same as `set/3`, but raises an exception if it fails.
  """
  @spec set!(Path.t(), name :: name_t, value :: binary) :: :ok | no_return
  def set!(path, name, value) do
    case set(path, name, value) do
      :ok ->
        :ok

      {:error, reason} ->
        raise Xattr.Error,
          reason: reason,
          action: "remove attribute of",
          path: IO.chardata_to_string(path)
    end
  end

  @doc """
  Removes extended attribute.

  If attribute `name` does not exist, `{:error, :enoattr}` is returned.

  ## Example

      Xattr.set("foo.txt", "hello", "world")
      Xattr.set("foo.txt", :foo, "bar")
      Xattr.rm("foo.txt", "foo")
      {:ok, ["hello"]} = Xattr.ls("foo.txt")
  """
  @spec rm(Path.t(), name :: name_t) :: :ok | {:error, term}
  def rm(path, name) when is_binary(name) or is_atom(name) do
    path = IO.chardata_to_string(path) <> <<0>>
    name = encode_name(name) <> <<0>>
    removexattr_nif(path, name)
  end

  @doc """
  The same as `rm/2`, but raises an exception if it fails.
  """
  @spec rm!(Path.t(), name :: name_t) :: :ok | no_return
  def rm!(path, name) do
    case rm(path, name) do
      :ok ->
        :ok

      {:error, reason} ->
        raise Xattr.Error,
          reason: reason,
          action: "remove attribute of",
          path: IO.chardata_to_string(path)
    end
  end

  defp encode_name(name) when is_atom(name) do
    @tag_atom <> to_string(name)
  end

  defp encode_name(name) when is_binary(name) do
    @tag_str <> name
  end

  defp decode_name(@tag_atom <> bin) do
    {:ok, String.to_atom(bin)}
  end

  defp decode_name(@tag_str <> bin) do
    {:ok, bin}
  end

  defp decode_name(_) do
    {:error, :invalfmt}
  end

  defp decode_list(lst) do
    decode_list(lst, {:ok, []})
  end

  defp decode_list([], acc) do
    acc
  end

  defp decode_list([name_enc | rest], {:ok, lst}) do
    case decode_name(name_enc) do
      {:ok, name} -> decode_list(rest, {:ok, [name | lst]})
      err -> err
    end
  end
end

defmodule Xattr.Error do
  defexception [:reason, :path, action: ""]

  def message(%{action: action, reason: reason, path: path}) do
    formatted = fmt(action, reason)
    "could not #{action} #{inspect(path)}: #{formatted}"
  end

  defp fmt(_action, :enoattr) do
    "no such attribute"
  end

  defp fmt(_action, :invalfmt) do
    "corrupted attribute data"
  end

  defp fmt(_action, reason) do
    case IO.iodata_to_binary(:file.format_error(reason)) do
      "unknown POSIX error" <> _ -> inspect(reason)
      formatted_reason -> formatted_reason
    end
  end
end
