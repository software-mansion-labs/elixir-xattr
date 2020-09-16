defmodule Xattr.Mixfile do
  use Mix.Project

  @version "0.4.0"

  def project do
    [
      app: :xattr,
      name: "Elixir Xattr",
      description: description(),
      version: @version,
      elixir: "~> 1.4",
      compilers: [:rustler] ++ Mix.compilers(),
      rustler_crates: [xattr_nif: []],
      source_url: "https://github.com/software-mansion-labs/elixir-xattr",
      docs: [
        source_ref: "v#{@version}",
        main: "readme",
        extras: ~w(README.md CHANGELOG.md)
      ],
      deps: deps(),
      package: package()
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp deps do
    [
      {:rustler, "~> 0.22-rc", runtime: false},

      # Development dependencies
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false}
    ]
  end

  defp description() do
    "Elixir library for accessing and manipulating custom extended filesystem attributes"
  end

  defp package() do
    [
      files: ~w(
        native/xattr_nif
        lib
        priv/.gitignore
        Makefile
        Makefile.win
        mix.exs
        README.md
        CHANGELOG.md
      ),
      maintainers: ["Marek Kaput <marek.kaput@swmansion.com>"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/software-mansion-labs/elixir-xattr"}
    ]
  end
end
