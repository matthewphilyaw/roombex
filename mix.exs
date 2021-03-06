defmodule Roombex.Mixfile do
  use Mix.Project 
  def project do
    [app: :roombex,
     version: "0.0.3",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     compilers: [:elixir, :app],
     aliases: aliases,
     deps: deps]
  end

  defp aliases do
    [clean: ["clean"]] 
  end
  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger],
     mod: {Roombex, ["/dev/pts/3", "115200"]}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:exjsx, ">= 3.1.0"}
    ]
  end
end

defmodule Mix.Tasks.Compile.Make do
  @short_doc "Runs make"

  def run(_) do
    {result, _err_code} = System.cmd("make", [], stderr_to_stdout: true)
    Mix.shell.info result
    
    :ok
  end 
end

defmodule Mix.Tasks.Clean.Make do
  @short_doc "Runs make clean"

  def run(_) do
    {result, _err_code} = System.cmd("make", ['clean'], stderr_to_stdout: true)
    Mix.shell.info result

    :ok
  end 
end
