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

    test "set(path, \"hello\", ...) creates new attr", %{path: path} do
      assert :ok == Xattr.set(path, "hello", "world")
      assert {:ok, "world"} == Xattr.get(path, "hello")
    end
  end

  describe "with foobar attrs" do
    setup [:new_file, :with_foobar_attrs]

    test "rm(path, \"foo\") removes this xattr and only \"bar\" remains",
         %{path: path} do
      assert :ok == Xattr.rm(path, "foo")
      assert {:ok, ["bar"]} == Xattr.ls(path)
    end

    test "set(path, \"hello\", ...) creates new attr", %{path: path} do
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

  describe "with empty attr" do
    setup [:new_file, :with_empty_attr]

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

    test "rm(path, \"empty\") removes empty", %{path: path} do
      assert :ok == Xattr.rm(path, "empty")
      assert {:error, :enoattr} == Xattr.get(path, "empty")
    end

    test "rm(path, \"hello\") returns {:error, :enoattr}", %{path: path} do
      assert {:error, :enoattr} == Xattr.rm(path, "hello")
    end
  end

  describe "with foobar and empty attrs" do
    setup [:new_file, :with_foobar_attrs, :with_empty_attr]

    test "ls/1 lists all of 'em", %{path: path} do
      assert {:ok, list} = Xattr.ls(path)
      assert ["bar", "empty", "foo"] == Enum.sort(list)
    end
  end

  describe "with UTF-8 file name and foobar & empty attrs" do
    setup [:new_utf8_file, :with_foobar_attrs, :with_empty_attr]

    test "ls/1 lists all attrs", %{path: path} do
      assert {:ok, list} = Xattr.ls(path)
      assert ["bar", "empty", "foo"] == Enum.sort(list)
    end

    test "set(path, \"empty\", \"hello\") overrides empty", %{path: path} do
      assert :ok == Xattr.set(path, "empty", "hello")
      assert {:ok, "hello"} == Xattr.get(path, "empty")
    end
  end

  describe "with UTF-8 file name and attrs" do
    setup [:new_utf8_file, :with_utf8_attrs]

    test "ls/1 lists all attrs", %{path: path} do
      assert {:ok, list} = Xattr.ls(path)
      assert Enum.sort(["ᚠᛇᚻ", "Τη γλώσσα", "我能吞"]) == Enum.sort(list)
    end

    test "has/2 works", %{path: path} do
      assert Xattr.has(path, "我能吞")
    end

    test "get/2 works", %{path: path} do
      assert {:ok, "我能吞下玻璃而不伤身体。"} == Xattr.get(path, "我能吞")
    end

    test "set/3 works", %{path: path} do
      assert :ok == Xattr.set(path, "我能吞", "ᚠᛇᚻ᛫ᛒᛦᚦ᛫ᚠᚱᚩᚠᚢᚱ᛫ᚠᛁᚱᚪ᛫ᚷᛖᚻᚹᛦᛚᚳᚢᛗ")
      assert {:ok, "ᚠᛇᚻ᛫ᛒᛦᚦ᛫ᚠᚱᚩᚠᚢᚱ᛫ᚠᛁᚱᚪ᛫ᚷᛖᚻᚹᛦᛚᚳᚢᛗ"} == Xattr.get(path, "我能吞")
    end

    test "rm/2 works", %{path: path} do
      assert :ok == Xattr.rm(path, "Τη γλώσσα")
      assert {:error, :enoattr} == Xattr.get(path, "Τη γλώσσα")
    end
  end

  for {name, fq} <- [
        {"ls/1",
         quote do
           &Xattr.ls(&1)
         end},
        {"has/2",
         quote do
           &Xattr.has(&1, "test")
         end},
        {"get/2",
         quote do
           &Xattr.get(&1, "test")
         end},
        {"set/3",
         quote do
           &Xattr.set(&1, "test", "hello")
         end},
        {"rm/2",
         quote do
           &Xattr.rm(&1, "test")
         end}
      ] do
    test "with non-existing file #{name} should return {:error, :enoent}" do
      path = "#{:erlang.unique_integer([:positive])}.test"
      assert {:error, :enoent} == unquote(fq).(path)
    end
  end

  describe "with atom attributes" do
    setup [:new_file, :with_atom_attrs]

    test "ls/1 lists all attrs", %{path: path} do
      assert {:ok, list} = Xattr.ls(path)
      assert Enum.sort([:abc, Foo.Bar, :"Hello World\n"]) == Enum.sort(list)
    end

    test "has/2 works", %{path: path} do
      assert Xattr.has(path, :abc)
    end

    test "get/2 works", %{path: path} do
      assert {:ok, "abc"} == Xattr.get(path, :abc)
    end

    test "set/3 works", %{path: path} do
      assert :ok == Xattr.set(path, :abc, "Hello World!")
      assert {:ok, "Hello World!"} == Xattr.get(path, :abc)
    end

    test "rm/2 works", %{path: path} do
      assert :ok == Xattr.rm(path, Foo.Bar)
      assert {:error, :enoattr} == Xattr.get(path, Foo.Bar)
    end
  end

  defp new_file(_context) do
    path = "#{:erlang.unique_integer([:positive])}.test"
    do_new_file(path)
  end

  defp new_utf8_file(_context) do
    path = "#{:erlang.unique_integer([:positive])}_சுப்ரமணிய.test"
    do_new_file(path)
  end

  defp do_new_file(path) do
    File.open!(path, [:read, :write], fn file ->
      IO.write(file, "hello world!")
    end)

    on_exit(fn ->
      File.rm!(path)
    end)

    {:ok, [path: path]}
  end

  defp with_foobar_attrs(%{path: path}) do
    :ok = Xattr.set(path, "foo", "foo")
    :ok = Xattr.set(path, "bar", "bar")
    {:ok, [path: path]}
  end

  defp with_empty_attr(%{path: path}) do
    :ok = Xattr.set(path, "empty", "")
    {:ok, [path: path]}
  end

  defp with_utf8_attrs(%{path: path}) do
    :ok = Xattr.set(path, "ᚠᛇᚻ", "ᚠᛇᚻ᛫ᛒᛦᚦ᛫ᚠᚱᚩᚠᚢᚱ᛫ᚠᛁᚱᚪ᛫ᚷᛖᚻᚹᛦᛚᚳᚢᛗ")
    :ok = Xattr.set(path, "Τη γλώσσα", "Τη γλώσσα μου έδωσαν ελληνική")
    :ok = Xattr.set(path, "我能吞", "我能吞下玻璃而不伤身体。")
    {:ok, [path: path]}
  end

  defp with_atom_attrs(%{path: path}) do
    :ok = Xattr.set(path, :abc, "abc")
    :ok = Xattr.set(path, Foo.Bar, "foobar")
    :ok = Xattr.set(path, :"Hello World\n", "Hello World\n")
    {:ok, [path: path]}
  end
end
