defmodule Xattr.Mixfile do
  use Mix.Project

  def project do
    [app: :elixir_xattr,
     version: "0.1.0",
     elixir: "~> 1.4.0",
     compilers: [:nif] ++ Mix.compilers,
     deps: deps()]
  end

  def application do
    [extra_applications: []]
  end

  defp deps do
    [
      # Development dependencies
      {:credo, "~> 0.8", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false}
    ]
  end
end

defmodule Mix.Tasks.Compile.Nif do
  use Mix.Task

  def run(_) do
    if match? {:win32, _}, :os.type do
      IO.warn("Windows is not supported.")
      exit(1)
    else
      {result, error_code} = System.cmd(
        "make", ["priv/elixir_xattr.so"], stderr_to_stdout: true)
      IO.binwrite result

      if error_code != 0 do
        raise Mix.Error, message: "make failed"
      end
    end

    Mix.Project.build_structure
    :ok
  end
end
