defmodule Xattr.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :xattr,
      name: "Elixir Xattr",
      description: description(),
      version: @version,
      elixir: "~> 1.4.0",
      compilers: [:elixir_make] ++ Mix.compilers,
      source_url: "https://github.com/SoftwareMansion/elixir-xattr",
      docs: [
        source_ref: "v#{@version}",
        main: "readme",
        extras: ~w(README.md LICENSE.md)
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
      {:elixir_make, "~> 0.4", runtime: false},

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
      files: ~w(c_src lib README.md LICENSE.md),
      maintainers: ["Marek Kaput <marek.kaput@swmansion.com>"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/SoftwareMansion/elixir-xattr"}
    ]
  end
end
