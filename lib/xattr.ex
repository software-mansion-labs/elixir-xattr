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

  ## Errors

  TODO:

  ## Implementation

  Elixir Xattr is implemented as NIF library with two platform-dependent backends:
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
  saved in simple binary format, as a contiguous list of *size:data* blocks:

  ```txt
    v - name C-string size           v - value binary size
  +---+------------+---+-----------+---+----------+---+-------+
  | 5 | n a m e \0 | 5 | v a l u e | 4 | f o o \0 | 3 | b a r |  ...
  +---+------------+---+-----------+---+----------+---+-------+
        ^ - name C-string, note \0 suffix               ^ - value binary data
  ```

  Both names nor values are not processed and stored as-is, that means names
  and values (if strings) are UTF-8 encoded.

  Unicode filenames are supported (and as such proper encoding conversions
  are performed).
  """

  @doc """
  Lists names of all extended attributes of `path`.

  The order of items in returned list is unspecified. If given `path` has no
  attributes, `{:ok, []}` is returned.

  ## Example

      Xattr.set("foo.txt", "hello", "world")
      Xattr.set("foo.txt", "foo", "bar")
      {:ok, list} = Xattr.ls("foo.txt")
      # list should be permutation of ["hello", "foo"]
  """
  @spec ls(Path.t) :: {:ok, list(String.t)} | {:error, term}
  def ls(path) do
    path = IO.chardata_to_string(path) <> <<0>>
    listxattr_nif(path)
  end

  @doc """
  Checks whether `path` has extended attribute `name`.

  ## Example

      Xattr.set("foo.txt", "hello", "world")
      Xattr.has("foo.txt", "hello") == {:ok, true}
      Xattr.has("foo.txt", "foo") == {:ok, false}
  """
  @spec has(Path.t, name :: String.t) :: {:ok, boolean} | {:error, term}
  def has(path, name) do
    path = IO.chardata_to_string(path) <> <<0>>
    name = name <> <<0>>
    hasxattr_nif(path, name)
  end

  @doc """
  Gets extended attribute value.

  If attribute `name` does not exist, `{:error, :enoattr}` is returned.

  ## Example

      Xattr.set("foo.txt", "hello", "world")
      Xattr.get("foo.txt", "hello") == {:ok, "world"}
      Xattr.get("foo.txt", "foo") == {:error, :enoattr}
  """
  @spec get(Path.t, name :: String.t) :: {:ok, binary} | {:error, term}
  def get(path, name) do
    path = IO.chardata_to_string(path) <> <<0>>
    name = name <> <<0>>
    getxattr_nif(path, name)
  end

  @doc """
  Sets extended attribute value.

  If attribute `name` does not exist, it is created.

  ## Example

      Xattr.set("foo.txt", "hello", "world")
      Xattr.get("foo.txt", "hello") == {:ok, "world"}
  """
  @spec set(
    Path.t,
    name :: String.t,
    value :: binary
  ) :: :ok | {:error, term}
  def set(path, name, value) do
    path = IO.chardata_to_string(path) <> <<0>>
    name = name <> <<0>>
    setxattr_nif(path, name, value)
  end

  @doc """
  Removes extended attribute.

  If attribute `name` does not exist, `{:error, :enoattr}` is returned.

  ## Example

      Xattr.set("foo.txt", "hello", "world")
      Xattr.set("foo.txt", "foo", "bar")
      Xattr.rm("foo.txt", "foo")
      {:ok, ["hello"]} = Xattr.ls("foo.txt")
  """
  @spec rm(Path.t, name :: String.t) :: :ok | {:error, term}
  def rm(path, name) do
    path = IO.chardata_to_string(path) <> <<0>>
    name = name <> <<0>>
    removexattr_nif(path, name)
  end
end
