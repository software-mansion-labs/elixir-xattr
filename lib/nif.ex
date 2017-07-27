defmodule Xattr.Nif do
  @on_load {:init, 0}

  @moduledoc false

  app = Mix.Project.config[:app]

  defp init do
    path = Path.join(:code.priv_dir(unquote(app)), "elixir_xattr")
    :erlang.load_nif(String.to_charlist(path), 0)
  end

  @spec listxattr_nif(binary) :: {:ok, list(binary)} | {:error, term}
  def listxattr_nif(_path) do
    :erlang.nif_error(:nif_library_not_loaded)
  end

  @spec hasxattr_nif(binary, binary) :: {:ok, boolean} | {:error, term}
  def hasxattr_nif(_path, _name) do
    :erlang.nif_error(:nif_library_not_loaded)
  end

  @spec getxattr_nif(binary, binary) :: {:ok, binary} | {:error, term}
  def getxattr_nif(_path, _name) do
    :erlang.nif_error(:nif_library_not_loaded)
  end

  @spec setxattr_nif(binary, binary, binary) :: :ok | {:error, term}
  def setxattr_nif(_path, _name, _value) do
    :erlang.nif_error(:nif_library_not_loaded)
  end

  @spec removexattr_nif(binary, binary) :: :ok | {:error, term}
  def removexattr_nif(_path, _name) do
    :erlang.nif_error(:nif_library_not_loaded)
  end
end
