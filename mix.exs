defmodule Xattr.Mixfile do
  use Mix.Project

  def project do
    [app: :elixir_xattr,
     version: "0.1.0",
     elixir: "~> 1.4.0",
     compilers: [:elixir_make] ++ Mix.compilers,
     deps: deps()]
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
end
