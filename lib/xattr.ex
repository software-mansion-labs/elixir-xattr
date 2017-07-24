defmodule Xattr do
  import Xattr.Nif

  @spec ls(Path.t) :: {:ok, list(String.t)} | {:error, term}
  def ls(path) do
    path = IO.chardata_to_string(path) <> <<0>>
    listxattr_nif(path)
  end

  @spec has(Path.t, name :: String.t) :: {:ok, boolean} | {:error, term}
  def has(path, name) do
    path = IO.chardata_to_string(path) <> <<0>>
    name = name <> <<0>>
    hasxattr_nif(path, name)
  end

  @spec get(Path.t, name :: String.t) :: {:ok, String.t} | {:error, term}
  def get(path, name) do
    path = IO.chardata_to_string(path) <> <<0>>
    name = name <> <<0>>
    getxattr_nif(path, name)
  end

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

  @spec rm(Path.t, name :: String.t) :: :ok | {:error, term}
  def rm(path, name) do
    path = IO.chardata_to_string(path) <> <<0>>
    name = name <> <<0>>
    removexattr_nif(path, name)
  end
end
