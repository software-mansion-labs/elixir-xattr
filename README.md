# Elixir Xattr

A library for accessing and manipulating custom [extended filesystem attributes](https://en.wikipedia.org/wiki/Extended_file_attributes). Main goals are to provide straightforward API and portability, Unix platforms are supported and Windows is also planned.

This library doesn't aim at supporting platform specific features, e.g. there is no (and won't be) possiblitity to access attributes from other namespaces than `user.` on Linux.

## Installation

The package can be installed by adding `elixir_xattr` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:elixir_xattr, "~> 0.1.0"}]
end
```
