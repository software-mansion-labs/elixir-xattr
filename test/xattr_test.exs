defmodule XattrTest do
  use ExUnit.Case, async: true

  describe "with fresh file" do
    setup [:new_file]

    test "ls/1 returns empty list", %{path: path} do
      assert {:ok, []} == Xattr.ls(path)
    end

    test "has/2 anyway returns false", %{path: path} do
      assert {:ok, false} == Xattr.has(path, "test")
    end

    test "rm/2 returns {:error, :enoattr}", %{path: path} do
      assert {:error, :enoattr} == Xattr.rm(path, "test")
    end

    test "set(path, \"hello\", ...) creates new tag", %{path: path} do
      assert :ok == Xattr.set(path, "hello", "world")
      assert {:ok, "world"} == Xattr.get(path, "hello")
    end
  end

  describe "with foobar tags" do
    setup [:new_file, :with_foobar_tags]

    test "rm(path, \"foo\") removes this xattr and only \"bar\" remains",
      %{path: path}
    do
      assert :ok == Xattr.rm(path, "foo")
      assert {:ok, ["bar"]} == Xattr.ls(path)
    end

    test "set(path, \"hello\", ...) creates new tag", %{path: path} do
      assert :ok == Xattr.set(path, "hello", "world")
      assert {:ok, "world"} == Xattr.get(path, "hello")
    end

    test "has(path, \"foo\") returns true", %{path: path} do
      assert {:ok, true} == Xattr.has(path, "foo")
    end

    test "has(path, \"hello\") returns false", %{path: path} do
      assert {:ok, false} == Xattr.has(path, "hello")
    end

    test "get(path, \"foo\") returns \"foo\"", %{path: path} do
      assert {:ok, "foo"} == Xattr.get(path, "foo")
    end

    test "get(path, \"bar\") returns \"bar\"", %{path: path} do
      assert {:ok, "bar"} == Xattr.get(path, "bar")
    end

    test "set(path, \"foo\", \"hello\") overrides foo", %{path: path} do
      assert :ok == Xattr.set(path, "foo", "hello")
      assert {:ok, "hello"} == Xattr.get(path, "foo")
    end

    test "set(path, \"foo\", \"\") overrides foo", %{path: path} do
      assert :ok == Xattr.set(path, "foo", "")
      assert {:ok, ""} == Xattr.get(path, "foo")
    end
  end

  describe "with empty tag" do
    setup [:new_file, :with_empty_tag]

    test "get(path, \"empty\") returns \"\"", %{path: path} do
      assert {:ok, ""} == Xattr.get(path, "empty")
    end

    test "has(path, \"empty\") returns true", %{path: path} do
      assert {:ok, true} == Xattr.has(path, "empty")
    end

    test "set(path, \"empty\", \"hello\") overrides empty", %{path: path} do
      assert :ok == Xattr.set(path, "empty", "hello")
      assert {:ok, "hello"} == Xattr.get(path, "empty")
    end
  end

  describe "with foobar and empty tags" do
    setup [:new_file, :with_foobar_tags, :with_empty_tag]

    test "ls/1 lists all of 'em", %{path: path} do
      assert {:ok, ["foo", "bar", "empty"]} == Xattr.ls(path)
    end
  end

  defp new_file(_context) do
    path = "#{:erlang.unique_integer([:positive])}.test"

    File.open!(path, [:read, :write], fn file ->
      IO.write(file, "hello world!")
    end)

    on_exit fn ->
      File.rm!(path)
    end

    {:ok, [path: path]}
  end

  defp with_foobar_tags(%{path: path}) do
    :ok = Xattr.set(path, "foo", "foo")
    :ok = Xattr.set(path, "bar", "bar")
    {:ok, [path: path]}
  end

  defp with_empty_tag(%{path: path}) do
    :ok = Xattr.set(path, "empty", "")
    {:ok, [path: path]}
  end
end
