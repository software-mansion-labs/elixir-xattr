# Elixir Xattr

[![Hex.pm](https://img.shields.io/hexpm/v/xattr.svg)](https://hex.pm/packages/xattr)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/xattr/)

A library for accessing and manipulating custom [extended filesystem attributes](https://en.wikipedia.org/wiki/Extended_file_attributes) on all systems, and system extended attributes on Unix-based systems. Main goals are to provide straightforward API and portability, both Windows (ADS) and Unix (xattr) platforms are supported.

This library doesn't aim to be a general extended filesystem attributes library, because implementation details greatly differ between supported platforms. Rather, it focuses on providing a portable way for client applications to store and read some metadata in files. Compatible attributes are stored in isolation, in *xattr* backend in `user.ElixirXattr` namespace and in *Windows* backend in `ElixirXattr` data stream. For details see *Implementation* section in module docs.

## Example

```elixir
iex(1)> File.touch!("foo.txt")
:ok
iex(2)> Xattr.set("foo.txt", "hello", "world")
:ok
iex(3)> Xattr.get("foo.txt", "hello")
{:ok, "world"}
iex(4)> Xattr.set("foo.txt", :atoms_also_work, "bar")
:ok
iex(5)> Xattr.ls("foo.txt")
{:ok, ["hello", :atoms_also_work]}
iex(6)> Xattr.rm("foo.txt", "hello")
:ok
iex(7)> Xattr.ls("foo.txt")
{:ok, [:atoms_also_work]}
```

On Unix-based systems, system attributes are supported too:

```elixir
iex(8)> Xattr.ls("elixir-xattr.tar.gz")
{:ok, ["user.xdg.origin.url"]}
iex(9)> Xattr.get("/usr/bin/dumpcap", "security.capability")
{:ok, <<1, 0, 0, 2, 0, 48, 0, 0, 0, 48, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>>}
```

## Installation

The package can be installed by adding `xattr` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:xattr, "~> 0.4"}]
end
```


## License

See the [LICENSE] file for license rights and limitations (MIT).

[LICENSE]: https://github.com/software-mansion-labs/elixir-xattr/blob/master/LICENSE.txt
